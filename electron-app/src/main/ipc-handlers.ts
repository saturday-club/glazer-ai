import { ipcMain, dialog, clipboard, BrowserWindow } from 'electron';
import { IPC } from '../shared/ipc-channels';
import type { CaptureRect, CaptureMode } from '../shared/types';
import { captureRegion } from './services/screen-capture';
import { recognizeText } from './services/ocr-service';
import { assemblePrompt } from './services/prompt-assembler';
import { queryWithText, queryWithVision } from './services/anthropic-client';
import { createResultsWindow } from './windows/results-window';
import { Constants } from './config/constants';
import store from './config/store';

/** Tracks open results windows to prevent garbage collection. */
const resultsWindows: Set<BrowserWindow> = new Set();

/**
 * Registers all IPC handlers. Called once during app initialization.
 */
export function registerIPCHandlers(): void {
  // Snipping confirmed: run the full pipeline.
  ipcMain.on(IPC.SNIPPING_CONFIRM, (_event, rect: CaptureRect) => {
    runPipeline(rect);
  });

  // Snipping cancelled: no-op (window is destroyed by the caller).
  ipcMain.on(IPC.SNIPPING_CANCEL, () => {
    // No-op.
  });

  // Copy text to clipboard.
  ipcMain.on(IPC.COPY_TO_CLIPBOARD, (_event, text: string) => {
    clipboard.writeText(text);
  });

  // Close the requesting window.
  ipcMain.on(IPC.CLOSE_WINDOW, (event) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    if (win) {
      resultsWindows.delete(win);
      win.close();
    }
  });

  // Settings handlers.
  ipcMain.handle(IPC.GET_API_KEY, () => store.get('apiKey'));
  ipcMain.handle(IPC.SET_API_KEY, (_event, key: string) => {
    store.set('apiKey', key);
  });
  ipcMain.handle(IPC.GET_CAPTURE_MODE, () => store.get('captureMode'));
  ipcMain.handle(IPC.SET_CAPTURE_MODE, (_event, mode: CaptureMode) => {
    store.set('captureMode', mode);
  });
}

/**
 * Runs the full pipeline: capture -> OCR/Vision -> Claude -> results.
 * Mirrors AppCoordinator.runPipeline() from the Swift version.
 */
async function runPipeline(rect: CaptureRect): Promise<void> {
  const apiKey = store.get('apiKey');
  if (!apiKey) {
    dialog.showErrorBox(
      'Glazer AI',
      'No API key configured. Open Settings from the tray menu and enter your Anthropic API key.'
    );
    return;
  }

  // Validate rect.
  if (rect.width < Constants.minimumSelectionSize || rect.height < Constants.minimumSelectionSize) {
    dialog.showErrorBox('Glazer AI', 'The selected region is too small to capture.');
    return;
  }

  // Create and show results window immediately (shows loading state).
  const resultsWin = createResultsWindow();
  resultsWindows.add(resultsWin);
  resultsWin.on('closed', () => resultsWindows.delete(resultsWin));

  // Wait for the renderer to be ready before sending updates.
  await new Promise<void>((resolve) => {
    resultsWin.webContents.once('did-finish-load', () => resolve());
  });

  const sendUpdate = (channel: string, payload: unknown) => {
    if (!resultsWin.isDestroyed()) {
      resultsWin.webContents.send(channel, payload);
    }
  };

  try {
    // Step 1: Capture.
    const pngBuffer = await captureRegion(rect);
    const imageBase64 = pngBuffer.toString('base64');
    sendUpdate(IPC.PIPELINE_IMAGE, imageBase64);

    const captureMode: CaptureMode = store.get('captureMode') || 'ocr';

    if (captureMode === 'vision') {
      // Vision mode: send image directly to Claude.
      const response = await queryWithVision(
        imageBase64,
        Constants.visionPromptTemplate,
        { apiKey }
      );
      sendUpdate(IPC.PIPELINE_RESPONSE, response);
    } else {
      // OCR mode: extract text, then query Claude.
      const ocrText = await recognizeText(pngBuffer);
      sendUpdate(IPC.PIPELINE_OCR, ocrText);

      const prompt = assemblePrompt(ocrText);
      console.log(`[Glazer AI] Prompt assembled (${prompt.length} chars)`);

      const response = await queryWithText(prompt, { apiKey });
      sendUpdate(IPC.PIPELINE_RESPONSE, response);
    }
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'An unknown error occurred.';
    sendUpdate(IPC.PIPELINE_ERROR, message);
    console.error('[Glazer AI] Pipeline error:', message);
  }
}

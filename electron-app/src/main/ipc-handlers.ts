import { ipcMain, dialog, clipboard, BrowserWindow } from 'electron';
import { IPC } from '../shared/ipc-channels';
import type { CaptureRect } from '../shared/types';
import { captureRegion } from './services/screen-capture';
import { recognizeText } from './services/ocr-service';
import { assemblePrompt } from './services/prompt-assembler';
import { runClaude, findClaudePath } from './services/claude-runner';
import { createResultsWindow } from './windows/results-window';
import { Constants } from './config/constants';

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
}

/**
 * Runs the full pipeline: capture -> OCR -> claude -p -> results.
 * Mirrors AppCoordinator.runPipeline() from the Swift version.
 */
async function runPipeline(rect: CaptureRect): Promise<void> {
  // Check that claude CLI is available.
  const claudePath = findClaudePath();
  if (!claudePath) {
    dialog.showErrorBox(
      'Glazer AI',
      'Claude CLI not found. Install it from https://claude.ai/download'
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

    // Step 2: OCR.
    const ocrText = await recognizeText(pngBuffer);
    sendUpdate(IPC.PIPELINE_OCR, ocrText);

    // Step 3: Assemble prompt.
    const prompt = assemblePrompt(ocrText);
    console.log(`[Glazer AI] Prompt assembled (${prompt.length} chars)`);

    // Step 4: Run claude -p.
    const response = await runClaude(prompt);
    sendUpdate(IPC.PIPELINE_RESPONSE, response);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'An unknown error occurred.';
    sendUpdate(IPC.PIPELINE_ERROR, message);
    console.error('[Glazer AI] Pipeline error:', message);
  }
}

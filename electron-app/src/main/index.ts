import { app, dialog, BrowserWindow } from 'electron';
import { createTray, destroyTray } from './tray';
import { registerGlobalShortcut, unregisterAllShortcuts } from './global-shortcut';
import { registerIPCHandlers } from './ipc-handlers';
import { createSnippingWindow } from './windows/snipping-window';
import { terminateOCR } from './services/ocr-service';
import { findClaudePath } from './services/claude-runner';
import { Constants } from './config/constants';

let snippingWindow: BrowserWindow | null = null;

/** Activates the snipping overlay. */
function startCapture(): void {
  // Prevent stacking multiple snipping windows.
  if (snippingWindow && !snippingWindow.isDestroyed()) {
    snippingWindow.focus();
    return;
  }

  snippingWindow = createSnippingWindow();

  snippingWindow.on('closed', () => {
    snippingWindow = null;
  });
}

/** Shows info about the app and claude CLI status. */
function openSettings(): void {
  const claudePath = findClaudePath();
  const status = claudePath
    ? `Claude CLI: ${claudePath}`
    : 'Claude CLI: NOT FOUND';

  dialog.showMessageBox({
    type: 'info',
    title: 'Glazer AI Settings',
    message: status,
    detail:
      'This app uses your local claude CLI (claude -p) for AI queries.\n' +
      'No API key needed -- claude handles its own authentication.\n\n' +
      'If claude is not found, install it from https://claude.ai/download',
    buttons: ['OK'],
  });
}

// ---- App lifecycle ----

// Enforce single instance.
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
}

// Hide from dock on macOS (menu bar only).
if (process.platform === 'darwin') {
  app.dock?.hide();
}

app.whenReady().then(async () => {
  // Register IPC handlers.
  registerIPCHandlers();

  // Create tray.
  createTray({
    onCapture: startCapture,
    onSettings: openSettings,
  });

  // Register global shortcut.
  registerGlobalShortcut(startCapture);

  // Check for claude CLI on first launch.
  const claudePath = findClaudePath();
  if (!claudePath) {
    await dialog.showMessageBox({
      type: 'warning',
      title: Constants.appName,
      message: 'Claude CLI not found',
      detail:
        'Glazer AI requires the Claude CLI to work.\n\n' +
        'Install it from https://claude.ai/download, then restart the app.',
      buttons: ['OK'],
    });
  }
});

app.on('will-quit', () => {
  unregisterAllShortcuts();
  destroyTray();
  terminateOCR();
});

// Keep the app running when all windows are closed (tray app).
app.on('window-all-closed', () => {
  // Do nothing -- app stays alive via system tray.
});

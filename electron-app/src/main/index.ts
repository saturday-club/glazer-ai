import { app, dialog, BrowserWindow } from 'electron';
import { createTray, destroyTray } from './tray';
import { registerGlobalShortcut, unregisterAllShortcuts } from './global-shortcut';
import { registerIPCHandlers } from './ipc-handlers';
import { createSnippingWindow } from './windows/snipping-window';
import { terminateOCR } from './services/ocr-service';
import { Constants } from './config/constants';
import store from './config/store';

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

/** Shows a dialog prompting the user to enter their API key. */
async function promptForApiKey(): Promise<void> {
  // On first launch with no key, show a notice. The actual key entry
  // happens via the Settings menu item (or a future settings window).
  const result = await dialog.showMessageBox({
    type: 'info',
    title: Constants.appName,
    message: 'Welcome to Glazer AI!',
    detail:
      'To get started, you need an Anthropic API key.\n\n' +
      'Right-click the tray icon and select "Settings..." to enter your key.',
    buttons: ['OK'],
  });
  // Future: open a proper settings window here.
  void result;
}

/** Placeholder settings handler. */
function openSettings(): void {
  // For v1, prompt for API key via input dialog.
  const currentKey = store.get('apiKey');
  const currentMode = store.get('captureMode') || 'ocr';

  // Use a simple message box approach for v1. A full settings window
  // can be added later.
  dialog
    .showMessageBox({
      type: 'question',
      title: 'Glazer AI Settings',
      message: `Current mode: ${currentMode}\nAPI Key: ${currentKey ? '***' + currentKey.slice(-4) : 'Not set'}`,
      detail: 'Use the buttons below to configure.',
      buttons: ['Set API Key', 'Toggle Mode', 'Close'],
    })
    .then(({ response }) => {
      if (response === 0) {
        // Prompt for API key. Electron has no built-in input dialog,
        // so we use a small BrowserWindow or process.stdin workaround.
        // For simplicity, use an environment variable fallback.
        promptApiKeyInput();
      } else if (response === 1) {
        const newMode = currentMode === 'ocr' ? 'vision' : 'ocr';
        store.set('captureMode', newMode);
        dialog.showMessageBox({
          type: 'info',
          title: 'Glazer AI',
          message: `Capture mode set to: ${newMode}`,
          buttons: ['OK'],
        });
      }
    });
}

function promptApiKeyInput(): void {
  // Create a tiny window for API key input.
  const inputWin = new BrowserWindow({
    width: 450,
    height: 180,
    resizable: false,
    title: 'Enter API Key',
    webPreferences: {
      contextIsolation: false,
      nodeIntegration: true,
    },
  });

  const currentKey = store.get('apiKey') || '';
  const html = `
    <html>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; padding: 20px; background: #1e1e1e; color: #fff;">
      <label style="display:block; margin-bottom: 8px; font-size: 14px;">Anthropic API Key:</label>
      <input id="key" type="password" value="${currentKey}"
        style="width: 100%; padding: 8px; font-size: 14px; border: 1px solid #555; border-radius: 4px; background: #2d2d2d; color: #fff; box-sizing: border-box;" />
      <div style="margin-top: 12px; text-align: right;">
        <button onclick="save()" style="padding: 6px 16px; font-size: 14px; border: none; border-radius: 4px; background: #007AFF; color: #fff; cursor: pointer;">Save</button>
        <button onclick="window.close()" style="padding: 6px 16px; font-size: 14px; border: 1px solid #555; border-radius: 4px; background: transparent; color: #fff; cursor: pointer; margin-left: 8px;">Cancel</button>
      </div>
      <script>
        const { ipcRenderer } = require('electron');
        function save() {
          const key = document.getElementById('key').value.trim();
          if (key) {
            require('electron').ipcRenderer.send('__set_api_key', key);
            window.close();
          }
        }
        document.getElementById('key').addEventListener('keydown', (e) => {
          if (e.key === 'Enter') save();
          if (e.key === 'Escape') window.close();
        });
        document.getElementById('key').focus();
      </script>
    </body>
    </html>
  `;

  inputWin.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`);
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

  // Listen for API key input from the settings mini-window.
  const { ipcMain } = await import('electron');
  ipcMain.on('__set_api_key', (_event, key: string) => {
    store.set('apiKey', key);
    dialog.showMessageBox({
      type: 'info',
      title: 'Glazer AI',
      message: 'API key saved.',
      buttons: ['OK'],
    });
  });

  // Create tray.
  createTray({
    onCapture: startCapture,
    onSettings: openSettings,
  });

  // Register global shortcut.
  registerGlobalShortcut(startCapture);

  // Check for API key on first launch.
  if (!store.get('apiKey')) {
    await promptForApiKey();
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

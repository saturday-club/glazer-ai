import { BrowserWindow } from 'electron';
import { join } from 'path';
import { getPrimaryDisplayBounds } from '../utils/platform';

/**
 * Creates a fullscreen, transparent, always-on-top snipping overlay window.
 * The renderer draws a dimmed canvas and captures mouse-drag region selection.
 */
export function createSnippingWindow(): BrowserWindow {
  const bounds = getPrimaryDisplayBounds();

  const win = new BrowserWindow({
    x: bounds.x,
    y: bounds.y,
    width: bounds.width,
    height: bounds.height,
    transparent: true,
    frame: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    movable: false,
    fullscreenable: false,
    hasShadow: false,
    webPreferences: {
      preload: join(__dirname, '..', 'preload', 'snipping.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  // Workaround: on Windows, fully transparent windows can have click-through
  // issues. Setting a near-transparent background prevents this.
  if (process.platform === 'win32') {
    win.setBackgroundColor('#01000000');
  }

  const isDev = !win.webContents.getURL() && process.env.NODE_ENV !== 'production';
  if (isDev) {
    win.loadURL('http://localhost:5173/snipping/index.html');
  } else {
    win.loadFile(join(__dirname, '..', 'renderer', 'snipping', 'index.html'));
  }

  win.setVisibleOnAllWorkspaces(true);

  return win;
}

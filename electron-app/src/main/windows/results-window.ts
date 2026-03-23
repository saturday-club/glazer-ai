import { BrowserWindow } from 'electron';
import { join } from 'path';
import { Constants } from '../config/constants';

/**
 * Creates a results window that displays the pipeline output.
 * Each capture opens a new results window (windows can stack).
 */
export function createResultsWindow(): BrowserWindow {
  const { minWidth, minHeight, defaultWidth, defaultHeight } =
    Constants.resultsWindow;

  const win = new BrowserWindow({
    width: defaultWidth,
    height: defaultHeight,
    minWidth,
    minHeight,
    title: 'Glazer AI -- Results',
    webPreferences: {
      preload: join(__dirname, '..', 'preload', 'results.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  const isDev = process.env.NODE_ENV !== 'production';
  if (isDev) {
    win.loadURL('http://localhost:5173/results/index.html');
  } else {
    win.loadFile(join(__dirname, '..', 'renderer', 'results', 'index.html'));
  }

  return win;
}

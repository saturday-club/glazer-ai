import { screen } from 'electron';

/** Returns the primary display's device pixel ratio. */
export function getScaleFactor(): number {
  return screen.getPrimaryDisplay().scaleFactor;
}

/** Returns the primary display's bounds in CSS pixels. */
export function getPrimaryDisplayBounds(): Electron.Rectangle {
  return screen.getPrimaryDisplay().bounds;
}

/** Returns true if running on macOS. */
export function isMac(): boolean {
  return process.platform === 'darwin';
}

/** Returns true if running on Windows. */
export function isWindows(): boolean {
  return process.platform === 'win32';
}

/** Returns true if running on Linux. */
export function isLinux(): boolean {
  return process.platform === 'linux';
}

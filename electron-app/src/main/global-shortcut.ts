import { globalShortcut } from 'electron';
import { Constants } from './config/constants';

/**
 * Registers the global keyboard shortcut (Cmd/Ctrl+Shift+2) to trigger capture.
 */
export function registerGlobalShortcut(onCapture: () => void): boolean {
  const registered = globalShortcut.register(
    Constants.shortcutAccelerator,
    onCapture
  );

  if (!registered) {
    console.warn(
      `[Glazer AI] Failed to register global shortcut: ${Constants.shortcutAccelerator}`
    );
  }

  return registered;
}

/** Unregisters all global shortcuts. Call on app quit. */
export function unregisterAllShortcuts(): void {
  globalShortcut.unregisterAll();
}

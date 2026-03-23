import { Tray, Menu, nativeImage, app } from 'electron';
import { join } from 'path';
import { isMac } from './utils/platform';

let tray: Tray | null = null;

interface TrayCallbacks {
  onCapture: () => void;
  onSettings: () => void;
}

/**
 * Creates the system tray icon with the context menu.
 * macOS: menu bar. Windows: system tray. Linux: AppIndicator.
 */
export function createTray(callbacks: TrayCallbacks): Tray {
  const iconName = isMac() ? 'tray-icon-Template.png' : 'tray-icon.png';
  const iconPath = join(__dirname, '..', '..', 'assets', 'icons', iconName);

  // Fallback to a simple 22x22 icon if the file does not exist.
  let icon: Electron.NativeImage;
  try {
    icon = nativeImage.createFromPath(iconPath);
    if (icon.isEmpty()) throw new Error('empty');
  } catch {
    // Create a minimal 22x22 circle icon as fallback.
    icon = nativeImage.createEmpty();
  }

  tray = new Tray(icon);
  tray.setToolTip('Glazer AI');

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Capture Region',
      click: callbacks.onCapture,
    },
    { type: 'separator' },
    {
      label: 'Settings...',
      click: callbacks.onSettings,
    },
    { type: 'separator' },
    {
      label: 'Quit Glazer AI',
      click: () => app.quit(),
    },
  ]);

  tray.setContextMenu(contextMenu);
  return tray;
}

export function destroyTray(): void {
  if (tray) {
    tray.destroy();
    tray = null;
  }
}

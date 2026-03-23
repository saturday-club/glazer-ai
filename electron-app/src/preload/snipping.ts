import { contextBridge, ipcRenderer } from 'electron';
import type { CaptureRect } from '../shared/types';

contextBridge.exposeInMainWorld('snippingAPI', {
  /** Sends the confirmed selection rect to the main process. */
  confirmSelection: (rect: CaptureRect) => {
    ipcRenderer.send('snipping:confirm', rect);
  },

  /** Cancels the snipping operation. */
  cancel: () => {
    ipcRenderer.send('snipping:cancel');
  },
});

import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('resultsAPI', {
  /** Subscribes to pipeline image updates. */
  onPipelineImage: (callback: (imageBase64: string) => void) => {
    ipcRenderer.on('pipeline:image', (_event, data) => callback(data));
  },

  /** Subscribes to pipeline OCR text updates. */
  onPipelineOcr: (callback: (text: string) => void) => {
    ipcRenderer.on('pipeline:ocr', (_event, data) => callback(data));
  },

  /** Subscribes to pipeline response updates. */
  onPipelineResponse: (callback: (text: string) => void) => {
    ipcRenderer.on('pipeline:response', (_event, data) => callback(data));
  },

  /** Subscribes to pipeline error updates. */
  onPipelineError: (callback: (message: string) => void) => {
    ipcRenderer.on('pipeline:error', (_event, data) => callback(data));
  },

  /** Copies text to the system clipboard via main process. */
  copyToClipboard: (text: string) => {
    ipcRenderer.send('clipboard:copy', text);
  },

  /** Closes this results window. */
  closeWindow: () => {
    ipcRenderer.send('window:close');
  },
});

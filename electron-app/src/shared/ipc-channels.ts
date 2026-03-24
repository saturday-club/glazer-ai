/** All IPC channel names. Single source of truth. */
export const IPC = {
  // Snipping -> Main
  SNIPPING_CONFIRM: 'snipping:confirm',
  SNIPPING_CANCEL: 'snipping:cancel',

  // Main -> Results
  PIPELINE_IMAGE: 'pipeline:image',
  PIPELINE_OCR: 'pipeline:ocr',
  PIPELINE_RESPONSE: 'pipeline:response',
  PIPELINE_ERROR: 'pipeline:error',

  // Results -> Main
  COPY_TO_CLIPBOARD: 'clipboard:copy',
  CLOSE_WINDOW: 'window:close',
} as const;

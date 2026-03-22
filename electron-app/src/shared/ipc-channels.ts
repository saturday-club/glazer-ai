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

  // Settings
  GET_API_KEY: 'settings:get-api-key',
  SET_API_KEY: 'settings:set-api-key',
  GET_CAPTURE_MODE: 'settings:get-capture-mode',
  SET_CAPTURE_MODE: 'settings:set-capture-mode',
} as const;

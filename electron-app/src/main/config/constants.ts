/** App-wide constants. Ported from Swift Constants.swift. */
export const Constants = {
  /** App display name. */
  appName: 'Glazer AI',

  /** Overlay dim opacity (0 = transparent, 1 = opaque). */
  overlayDimOpacity: 0.4,

  /** Selection border color (Apple Blue #007AFF). */
  selectionBorderColor: '#007AFF',

  /** Selection border width in pixels. */
  selectionBorderWidth: 1,

  /** Minimum selection size in CSS pixels to accept a capture. */
  minimumSelectionSize: 4,

  /** Tray icon size in pixels. */
  trayIconSize: 22,

  /** Results window dimensions. */
  resultsWindow: {
    minWidth: 500,
    minHeight: 400,
    defaultWidth: 600,
    defaultHeight: 600,
  },

  /** Dimension label font. */
  dimensionLabelFont: '11px "SF Mono", "Consolas", "Courier New", monospace',

  /** Global keyboard shortcut accelerator. */
  shortcutAccelerator: 'CommandOrControl+Shift+2',

  /** Anthropic API defaults. */
  anthropic: {
    defaultModel: 'claude-sonnet-4-20250514',
    maxTokens: 4096,
    timeoutMs: 60_000,
  },

  /** Default research prompt template. */
  defaultPromptTemplate:
    'The following text was extracted from a screenshot. ' +
    'Please research this topic thoroughly and provide a concise, ' +
    'well-structured summary with key facts and relevant context:\n\n{ocr_text}',

  /** Vision mode prompt (sent with the image). */
  visionPromptTemplate:
    'Analyze this screenshot. Research the topic shown thoroughly and provide ' +
    'a concise, well-structured summary with key facts and relevant context.',
} as const;

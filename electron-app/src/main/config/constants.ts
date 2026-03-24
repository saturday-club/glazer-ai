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

  /** Claude CLI timeout in milliseconds. */
  claudeTimeoutMs: 120_000,

  /** Default research prompt template. */
  defaultPromptTemplate:
    'You are a research assistant. Analyze the text below extracted from a screenshot.\n\n' +
    'Provide a direct, well-structured summary with key facts and relevant context.\n\n' +
    'Anti-slop rules for your response:\n' +
    '- No adverbs (no -ly words, no "really", "just", "genuinely")\n' +
    '- No throat-clearing ("Here\'s the thing", "It turns out", "Let me be clear")\n' +
    '- No business jargon ("navigate", "landscape", "lean into", "deep dive")\n' +
    '- No vague emphasis ("This matters because", "Make no mistake")\n' +
    '- No false agency (objects doing human actions)\n' +
    '- Active voice only. Name who does what.\n' +
    '- State facts directly. No filler, no hedging.\n\n' +
    '{ocr_text}',

} as const;

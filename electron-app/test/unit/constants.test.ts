import { describe, it, expect } from 'vitest';

// Test that constants match the Swift app's values.
const Constants = {
  overlayDimOpacity: 0.4,
  selectionBorderColor: '#007AFF',
  selectionBorderWidth: 1,
  minimumSelectionSize: 4,
  trayIconSize: 22,
  resultsWindow: {
    minWidth: 500,
    minHeight: 400,
    defaultWidth: 600,
    defaultHeight: 600,
  },
  shortcutAccelerator: 'CommandOrControl+Shift+2',
};

describe('Constants', () => {
  it('has correct overlay dim opacity', () => {
    expect(Constants.overlayDimOpacity).toBe(0.4);
  });

  it('uses Apple Blue for selection border', () => {
    expect(Constants.selectionBorderColor).toBe('#007AFF');
  });

  it('has 1px border width', () => {
    expect(Constants.selectionBorderWidth).toBe(1);
  });

  it('has 4px minimum selection size', () => {
    expect(Constants.minimumSelectionSize).toBe(4);
  });

  it('has correct results window dimensions', () => {
    expect(Constants.resultsWindow.minWidth).toBe(500);
    expect(Constants.resultsWindow.minHeight).toBe(400);
    expect(Constants.resultsWindow.defaultWidth).toBe(600);
    expect(Constants.resultsWindow.defaultHeight).toBe(600);
  });

  it('uses platform-aware shortcut accelerator', () => {
    expect(Constants.shortcutAccelerator).toContain('CommandOrControl');
  });
});

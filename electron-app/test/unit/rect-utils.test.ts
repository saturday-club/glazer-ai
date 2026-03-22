import { describe, it, expect } from 'vitest';

// Pure function: normalize a rect with potentially negative width/height.
interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

function normalizeRect(rect: Rect): Rect {
  return {
    x: rect.width < 0 ? rect.x + rect.width : rect.x,
    y: rect.height < 0 ? rect.y + rect.height : rect.y,
    width: Math.abs(rect.width),
    height: Math.abs(rect.height),
  };
}

describe('normalizeRect', () => {
  it('returns the same rect if width/height are positive', () => {
    const rect = { x: 10, y: 20, width: 100, height: 50 };
    expect(normalizeRect(rect)).toEqual(rect);
  });

  it('normalizes negative width (drag left)', () => {
    const rect = { x: 110, y: 20, width: -100, height: 50 };
    expect(normalizeRect(rect)).toEqual({ x: 10, y: 20, width: 100, height: 50 });
  });

  it('normalizes negative height (drag up)', () => {
    const rect = { x: 10, y: 70, width: 100, height: -50 };
    expect(normalizeRect(rect)).toEqual({ x: 10, y: 20, width: 100, height: 50 });
  });

  it('normalizes both negative width and height', () => {
    const rect = { x: 110, y: 70, width: -100, height: -50 };
    expect(normalizeRect(rect)).toEqual({ x: 10, y: 20, width: 100, height: 50 });
  });

  it('handles zero dimensions', () => {
    const rect = { x: 50, y: 50, width: 0, height: 0 };
    expect(normalizeRect(rect)).toEqual({ x: 50, y: 50, width: 0, height: 0 });
  });
});

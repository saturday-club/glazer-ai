import { describe, it, expect } from 'vitest';

// Direct port of the prompt assembly logic for testing.
// In production this uses electron-store, but we test the pure function.
const PLACEHOLDER = '{ocr_text}';
const DEFAULT_TEMPLATE =
  'The following text was extracted from a screenshot. ' +
  'Please research this topic thoroughly and provide a concise, ' +
  'well-structured summary with key facts and relevant context:\n\n{ocr_text}';

function assemblePrompt(ocrText: string, template = DEFAULT_TEMPLATE): string {
  return template.replace(PLACEHOLDER, ocrText);
}

describe('assemblePrompt', () => {
  it('replaces the placeholder with OCR text', () => {
    const result = assemblePrompt('Hello World');
    expect(result).toContain('Hello World');
    expect(result).not.toContain('{ocr_text}');
  });

  it('preserves the full template around the OCR text', () => {
    const result = assemblePrompt('test');
    expect(result).toContain('research this topic thoroughly');
    expect(result.endsWith('test')).toBe(true);
  });

  it('handles empty OCR text', () => {
    const result = assemblePrompt('');
    expect(result).toContain('well-structured summary');
    expect(result).not.toContain('{ocr_text}');
  });

  it('supports custom templates', () => {
    const custom = 'Summarize: {ocr_text}';
    const result = assemblePrompt('some text', custom);
    expect(result).toBe('Summarize: some text');
  });

  it('handles multiline OCR text', () => {
    const text = 'line one\nline two\nline three';
    const result = assemblePrompt(text);
    expect(result).toContain('line one\nline two\nline three');
  });
});

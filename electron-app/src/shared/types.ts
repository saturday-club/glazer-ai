/** Rectangle in CSS pixels from the snipping overlay. */
export interface CaptureRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

/** Progressive pipeline update sent from main to results renderer. */
export type PipelineUpdate =
  | { type: 'image'; imageBase64: string }
  | { type: 'ocr'; text: string }
  | { type: 'response'; text: string }
  | { type: 'error'; message: string };

/** Pipeline result state for the results window. */
export type PipelineState = 'loading' | 'ocr-complete' | 'success' | 'error';

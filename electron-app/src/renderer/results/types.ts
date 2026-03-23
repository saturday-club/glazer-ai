/** Results window state. Mirrors Swift ResultsViewModel. */
export interface ResultsState {
  /** Pipeline phase. */
  status: 'loading' | 'success' | 'error';

  /** Base64-encoded PNG thumbnail of the captured region. */
  imageBase64: string | null;

  /** Raw OCR text (empty in vision mode). */
  ocrText: string;

  /** Claude's response text. */
  responseText: string | null;

  /** Error message if the pipeline failed. */
  errorMessage: string | null;

  /** Whether the OCR text section is expanded. */
  isOcrExpanded: boolean;
}

export const initialState: ResultsState = {
  status: 'loading',
  imageBase64: null,
  ocrText: '',
  responseText: null,
  errorMessage: null,
  isOcrExpanded: false,
};

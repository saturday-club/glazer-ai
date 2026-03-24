import { Constants } from '../config/constants';

const PLACEHOLDER = '{ocr_text}';

/**
 * Replaces the {ocr_text} placeholder in the template with the recognized text.
 */
export function assemblePrompt(ocrText: string): string {
  return Constants.defaultPromptTemplate.replace(PLACEHOLDER, ocrText);
}

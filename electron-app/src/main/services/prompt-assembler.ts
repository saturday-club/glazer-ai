import { Constants } from '../config/constants';
import store from '../config/store';

const PLACEHOLDER = '{ocr_text}';

/**
 * Replaces the {ocr_text} placeholder in the template with the recognized text.
 * Uses the user's custom template if set, otherwise the default.
 */
export function assemblePrompt(ocrText: string): string {
  const template =
    store.get('promptTemplate') || Constants.defaultPromptTemplate;
  return template.replace(PLACEHOLDER, ocrText);
}

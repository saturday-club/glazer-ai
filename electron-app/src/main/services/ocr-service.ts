import Tesseract from 'tesseract.js';

let worker: Tesseract.Worker | null = null;

/**
 * Initializes the Tesseract worker if needed and recognizes text from a PNG buffer.
 *
 * @param pngBuffer - PNG image data.
 * @returns Recognized text string.
 * @throws If no text is detected.
 */
export async function recognizeText(pngBuffer: Buffer): Promise<string> {
  if (!worker) {
    worker = await Tesseract.createWorker('eng');
  }

  const {
    data: { text },
  } = await worker.recognize(pngBuffer);

  const trimmed = text.trim();
  if (!trimmed) {
    throw new Error('No text was detected in the captured region.');
  }

  return trimmed;
}

/** Terminates the worker. Call on app quit. */
export async function terminateOCR(): Promise<void> {
  if (worker) {
    await worker.terminate();
    worker = null;
  }
}

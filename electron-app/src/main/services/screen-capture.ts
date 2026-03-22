import screenshot from 'screenshot-desktop';
import sharp from 'sharp';
import type { CaptureRect } from '../../shared/types';
import { getScaleFactor } from '../utils/platform';

/**
 * Captures the full primary screen, then crops to the selected region.
 *
 * @param rect - Selection rectangle in CSS pixels.
 * @returns PNG buffer of the cropped region.
 */
export async function captureRegion(rect: CaptureRect): Promise<Buffer> {
  // Capture full screen as PNG buffer.
  const fullScreenBuffer = await screenshot({ format: 'png' }) as Buffer;

  const scale = getScaleFactor();

  // Scale the CSS-pixel rect to device pixels for cropping.
  const cropRegion = {
    left: Math.round(rect.x * scale),
    top: Math.round(rect.y * scale),
    width: Math.round(rect.width * scale),
    height: Math.round(rect.height * scale),
  };

  // Clamp to valid dimensions.
  if (cropRegion.width < 1 || cropRegion.height < 1) {
    throw new Error('The selected region is too small to capture.');
  }

  const cropped = await sharp(fullScreenBuffer)
    .extract(cropRegion)
    .png()
    .toBuffer();

  return cropped;
}

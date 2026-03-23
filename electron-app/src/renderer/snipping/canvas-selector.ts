/**
 * Canvas-based region selector. Ported from SnippingView.swift.
 *
 * Draws a dimmed overlay over the full screen, lets the user drag to select
 * a rectangle which is drawn at full brightness with a blue border and
 * dimension label.
 */

/** Selection border color (Apple Blue). */
const BORDER_COLOR = '#007AFF';
const BORDER_WIDTH = 1;
const DIM_OPACITY = 0.4;
const MIN_SIZE = 4;
const LABEL_FONT = '11px "SF Mono", "Consolas", "Courier New", monospace';
const LABEL_PADDING = 4;

export interface SelectionRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

type ConfirmCallback = (rect: SelectionRect) => void;
type CancelCallback = () => void;

export class CanvasSelector {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private isDragging = false;
  private anchorX = 0;
  private anchorY = 0;
  private currentX = 0;
  private currentY = 0;

  private onConfirm: ConfirmCallback;
  private onCancel: CancelCallback;

  constructor(
    canvas: HTMLCanvasElement,
    onConfirm: ConfirmCallback,
    onCancel: CancelCallback
  ) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d')!;
    this.onConfirm = onConfirm;
    this.onCancel = onCancel;

    this.resize();
    this.bindEvents();
    this.draw();
  }

  private resize(): void {
    const dpr = window.devicePixelRatio || 1;
    this.canvas.width = window.innerWidth * dpr;
    this.canvas.height = window.innerHeight * dpr;
    this.canvas.style.width = `${window.innerWidth}px`;
    this.canvas.style.height = `${window.innerHeight}px`;
    this.ctx.scale(dpr, dpr);
  }

  private bindEvents(): void {
    this.canvas.addEventListener('mousedown', this.onMouseDown);
    this.canvas.addEventListener('mousemove', this.onMouseMove);
    this.canvas.addEventListener('mouseup', this.onMouseUp);
    window.addEventListener('keydown', this.onKeyDown);
  }

  private onMouseDown = (e: MouseEvent): void => {
    this.isDragging = true;
    this.anchorX = e.clientX;
    this.anchorY = e.clientY;
    this.currentX = e.clientX;
    this.currentY = e.clientY;
  };

  private onMouseMove = (e: MouseEvent): void => {
    if (!this.isDragging) return;
    this.currentX = e.clientX;
    this.currentY = e.clientY;
    this.draw();
  };

  private onMouseUp = (): void => {
    if (!this.isDragging) return;
    this.isDragging = false;

    const rect = this.normalizedRect();
    if (rect.width < MIN_SIZE || rect.height < MIN_SIZE) {
      this.onCancel();
      return;
    }

    this.onConfirm(rect);
  };

  private onKeyDown = (e: KeyboardEvent): void => {
    if (e.key === 'Escape') {
      this.onCancel();
    }
  };

  /** Returns the selection rect with positive width/height. */
  private normalizedRect(): SelectionRect {
    const rawW = this.currentX - this.anchorX;
    const rawH = this.currentY - this.anchorY;
    return {
      x: rawW < 0 ? this.anchorX + rawW : this.anchorX,
      y: rawH < 0 ? this.anchorY + rawH : this.anchorY,
      width: Math.abs(rawW),
      height: Math.abs(rawH),
    };
  }

  private draw(): void {
    const ctx = this.ctx;
    const w = window.innerWidth;
    const h = window.innerHeight;

    // Clear everything.
    ctx.clearRect(0, 0, w, h);

    // Full-screen dim layer.
    ctx.fillStyle = `rgba(0, 0, 0, ${DIM_OPACITY})`;
    ctx.fillRect(0, 0, w, h);

    if (!this.isDragging) return;

    const rect = this.normalizedRect();
    if (rect.width < MIN_SIZE || rect.height < MIN_SIZE) return;

    // Clear the selected region (show screen through).
    ctx.clearRect(rect.x, rect.y, rect.width, rect.height);

    // Blue 1pt border.
    ctx.strokeStyle = BORDER_COLOR;
    ctx.lineWidth = BORDER_WIDTH;
    ctx.strokeRect(rect.x, rect.y, rect.width, rect.height);

    // Dimension label near bottom-right of selection.
    this.drawDimensionLabel(rect);
  }

  private drawDimensionLabel(rect: SelectionRect): void {
    const ctx = this.ctx;
    const label = `${Math.round(rect.width)} x ${Math.round(rect.height)}`;

    ctx.font = LABEL_FONT;
    ctx.fillStyle = '#ffffff';

    const metrics = ctx.measureText(label);
    const labelW = metrics.width;
    const labelH = 14; // approximate line height for 11px font

    const lx = rect.x + rect.width - labelW - LABEL_PADDING;
    const ly = rect.y + rect.height + labelH + LABEL_PADDING;

    // Background pill for readability.
    ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
    ctx.beginPath();
    ctx.roundRect(lx - 4, ly - labelH, labelW + 8, labelH + 4, 3);
    ctx.fill();

    // Label text.
    ctx.fillStyle = '#ffffff';
    ctx.fillText(label, lx, ly);
  }

  /** Cleanup event listeners. */
  destroy(): void {
    this.canvas.removeEventListener('mousedown', this.onMouseDown);
    this.canvas.removeEventListener('mousemove', this.onMouseMove);
    this.canvas.removeEventListener('mouseup', this.onMouseUp);
    window.removeEventListener('keydown', this.onKeyDown);
  }
}

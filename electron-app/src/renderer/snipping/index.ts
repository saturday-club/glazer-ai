import { CanvasSelector, type SelectionRect } from './canvas-selector';

// Type declaration for the preload bridge.
declare global {
  interface Window {
    snippingAPI: {
      confirmSelection: (rect: SelectionRect) => void;
      cancel: () => void;
    };
  }
}

const canvas = document.getElementById('snipping-canvas') as HTMLCanvasElement;

const selector = new CanvasSelector(
  canvas,
  (rect) => {
    window.snippingAPI.confirmSelection(rect);
    // Close the snipping window after confirming.
    window.close();
  },
  () => {
    window.snippingAPI.cancel();
    window.close();
  }
);

// Cleanup on unload.
window.addEventListener('beforeunload', () => {
  selector.destroy();
});

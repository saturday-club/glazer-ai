import { useState, useEffect } from 'react';
import { initialState, type ResultsState } from '../types';

// Type declaration for the preload bridge.
declare global {
  interface Window {
    resultsAPI: {
      onPipelineImage: (cb: (imageBase64: string) => void) => void;
      onPipelineOcr: (cb: (text: string) => void) => void;
      onPipelineResponse: (cb: (text: string) => void) => void;
      onPipelineError: (cb: (message: string) => void) => void;
      copyToClipboard: (text: string) => void;
      closeWindow: () => void;
    };
  }
}

/**
 * Hook that subscribes to pipeline updates from the main process
 * and maintains the results window state.
 */
export function usePipelineState(): ResultsState {
  const [state, setState] = useState<ResultsState>(initialState);

  useEffect(() => {
    window.resultsAPI.onPipelineImage((imageBase64) => {
      setState((prev) => ({ ...prev, imageBase64 }));
    });

    window.resultsAPI.onPipelineOcr((text) => {
      setState((prev) => ({ ...prev, ocrText: text }));
    });

    window.resultsAPI.onPipelineResponse((text) => {
      setState((prev) => ({
        ...prev,
        status: 'success',
        responseText: text,
      }));
    });

    window.resultsAPI.onPipelineError((message) => {
      setState((prev) => ({
        ...prev,
        status: 'error',
        errorMessage: message,
      }));
    });
  }, []);

  return state;
}

import { usePipelineState } from './hooks/usePipelineState';
import { ImageThumbnail } from './components/ImageThumbnail';
import { OcrSection } from './components/OcrSection';
import { ResponseSection } from './components/ResponseSection';
import { ActionButtons } from './components/ActionButtons';

export function App() {
  const state = usePipelineState();

  return (
    <div className="results-container">
      <ImageThumbnail imageBase64={state.imageBase64} />
      <OcrSection ocrText={state.ocrText} />
      <ResponseSection
        status={state.status}
        responseText={state.responseText}
        errorMessage={state.errorMessage}
      />
      <ActionButtons responseText={state.responseText} />
    </div>
  );
}

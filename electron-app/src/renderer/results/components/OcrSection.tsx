import { useState } from 'react';

interface Props {
  ocrText: string;
}

export function OcrSection({ ocrText }: Props) {
  const [expanded, setExpanded] = useState(false);

  if (!ocrText) return null;

  return (
    <div className="section">
      <div className="ocr-header" onClick={() => setExpanded(!expanded)}>
        <span className={`toggle ${expanded ? 'expanded' : ''}`}>&#9654;</span>
        <span className="section-title">Extracted Text</span>
      </div>
      {expanded && <div className="mono-block">{ocrText}</div>}
    </div>
  );
}

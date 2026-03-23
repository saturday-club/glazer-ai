interface Props {
  status: 'loading' | 'success' | 'error';
  responseText: string | null;
  errorMessage: string | null;
}

export function ResponseSection({ status, responseText, errorMessage }: Props) {
  if (status === 'loading') {
    return (
      <div className="section loading">
        <div className="spinner" />
        <span>Thinking...</span>
      </div>
    );
  }

  if (status === 'error') {
    return (
      <div className="section">
        <div className="section-title error-title">Error</div>
        <div className="error-message">{errorMessage}</div>
      </div>
    );
  }

  if (status === 'success' && responseText) {
    return (
      <div className="section">
        <div className="section-title">Claude's Response</div>
        <div className="mono-block">{responseText}</div>
      </div>
    );
  }

  return null;
}

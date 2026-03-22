interface Props {
  responseText: string | null;
}

export function ActionButtons({ responseText }: Props) {
  const handleCopy = () => {
    if (responseText) {
      window.resultsAPI.copyToClipboard(responseText);
    }
  };

  const handleClose = () => {
    window.resultsAPI.closeWindow();
  };

  return (
    <div className="action-buttons">
      {responseText ? (
        <button className="btn btn-primary" onClick={handleCopy}>
          Copy Response
        </button>
      ) : (
        <div />
      )}
      <button className="btn btn-secondary" onClick={handleClose}>
        Close
      </button>
    </div>
  );
}

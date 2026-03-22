interface Props {
  imageBase64: string | null;
}

export function ImageThumbnail({ imageBase64 }: Props) {
  if (!imageBase64) return null;

  return (
    <div className="section">
      <img
        className="thumbnail"
        src={`data:image/png;base64,${imageBase64}`}
        alt="Captured region"
      />
    </div>
  );
}

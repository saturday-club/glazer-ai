// OCRService.swift
// GlazerAI
//
// Extracts text from a captured image using the Vision framework.

import Foundation
import Vision

// MARK: - Errors

/// Errors produced by ``OCRService``.
enum OCRError: LocalizedError {
    /// No text was detected in the image.
    case noTextFound
    /// The Vision request failed.
    case recognitionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text was detected in the captured region."
        case .recognitionFailed(let error):
            return "Text recognition failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Service

/// Performs OCR on a PNG image using `VNRecognizeTextRequest`.
final class OCRService: Sendable {

    /// Recognises text in the given PNG image data.
    ///
    /// - Parameter imageData: PNG-encoded image data.
    /// - Returns: All recognised text observations joined by newline.
    /// - Throws: ``OCRError`` if recognition fails or no text is found.
    func recognizeText(in imageData: Data) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = createCGImage(from: imageData) else {
                continuation.resume(
                    throwing: OCRError.recognitionFailed(
                        underlying: NSError(
                            domain: "OCRService",
                            code: -1,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Failed to create image from data"
                            ]
                        )
                    )
                )
                return
            }

            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.recognitionFailed(underlying: error))
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                if lines.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: lines.joined(separator: "\n"))
                }
            }

            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(underlying: error))
            }
        }
    }

    // MARK: - Private

    /// Creates a CGImage from PNG data.
    private func createCGImage(from data: Data) -> CGImage? {
        guard let dataProvider = CGDataProvider(data: data as CFData),
              let source = CGImageSourceCreateWithDataProvider(dataProvider, nil),
              CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

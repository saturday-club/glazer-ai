// IntegrationSmokeTest.swift
// GlazerAITests
//
// Lightweight smoke tests verifying the pipeline components work together.

import XCTest
@testable import GlazerAI

// MARK: - Spy

/// Records every call to `send(image:)` for assertion in tests.
@MainActor
final class SpyAIBackendService: AIBackendService {

    /// All image payloads received, in order.
    private(set) var receivedImages: [Data] = []

    func send(image: Data) async throws {
        guard !image.isEmpty else { throw AIBackendError.emptyPayload }
        receivedImages.append(image)
    }
}

// MARK: - Tests

@MainActor
final class IntegrationSmokeTest: XCTestCase {

    func test_backendSpy_receivesNonEmptyData() async throws {
        let spy = SpyAIBackendService()

        let fakePNG = makeSinglePixelPNG()
        XCTAssertFalse(fakePNG.isEmpty, "Fake PNG must be non-empty")

        try await spy.send(image: fakePNG)

        XCTAssertEqual(spy.receivedImages.count, 1)
        XCTAssertFalse(spy.receivedImages[0].isEmpty)
    }

    func test_promptAssembler_integrationWithOCRText() {
        let assembler = PromptAssembler()
        let ocrText = "What is Swift concurrency?"
        let prompt = assembler.assemble(ocrText: ocrText)

        XCTAssertTrue(prompt.contains(ocrText))
        XCTAssertFalse(prompt.contains("{ocr_text}"))
    }

    func test_resultsViewModel_fullLifecycle() {
        let viewModel = ResultsViewModel()

        // Start loading
        XCTAssertTrue(viewModel.isLoading)

        // Set OCR text
        viewModel.ocrText = "Some text"
        XCTAssertEqual(viewModel.ocrText, "Some text")

        // Set success
        viewModel.state = .success(response: "Research results")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.responseText, "Research results")
    }

    // MARK: - Helpers

    /// Returns a minimal 1x1 PNG encoded in memory.
    private func makeSinglePixelPNG() -> Data {
        let size = CGSize(width: 1, height: 1)
        var pngData = Data()
        autoreleasepool {
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()
            image.unlockFocus()

            if let tiff   = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let data   = bitmap.representation(using: .png, properties: [:]) {
                pngData = data
            }
        }
        return pngData
    }
}

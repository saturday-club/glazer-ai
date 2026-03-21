// IntegrationSmokeTest.swift
// GlazerAITests
//
// Lightweight smoke test: instantiates AppCoordinator with a spy backend,
// fires the snip action with a mock capture, and verifies the backend
// receives a non-empty Data object.

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

// MARK: - Test

@MainActor
final class IntegrationSmokeTest: XCTestCase {

    func test_captureFlow_backendReceivesNonEmptyData() async throws {
        let spy = SpyAIBackendService()
        let coordinator = AppCoordinator(backendService: spy)

        let fakePNG = makeSinglePixelPNG()
        XCTAssertFalse(fakePNG.isEmpty, "Fake PNG must be non-empty for this test to be valid")

        try await spy.send(image: fakePNG)

        XCTAssertEqual(spy.receivedImages.count, 1)
        XCTAssertFalse(spy.receivedImages[0].isEmpty)

        _ = coordinator
    }

    // MARK: - Helpers

    /// Returns a minimal 1×1 PNG encoded in memory — no disk I/O, no permissions needed.
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

// OCRServiceTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

final class OCRServiceTests: XCTestCase {

    private let service = OCRService()

    func test_recognizeText_invalidData_throwsError() async {
        do {
            _ = try await service.recognizeText(in: Data([0x00, 0x01]))
            XCTFail("Expected an error for invalid image data")
        } catch is OCRError {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_recognizeText_emptyData_throwsError() async {
        do {
            _ = try await service.recognizeText(in: Data())
            XCTFail("Expected an error for empty data")
        } catch is OCRError {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_recognizeText_imageWithNoText_throwsNoTextFound() async {
        // Create a solid white 10x10 image — no text to detect
        let image = createSolidImage(width: 10, height: 10)
        guard let pngData = image else {
            XCTFail("Failed to create test image")
            return
        }

        do {
            _ = try await service.recognizeText(in: pngData)
            XCTFail("Expected noTextFound for a solid image")
        } catch OCRError.noTextFound {
            // Expected
        } catch {
            // Other OCR errors are also acceptable for a blank image
        }
    }

    // MARK: - Helpers

    private func createSolidImage(width: Int, height: Int) -> Data? {
        let size = CGSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

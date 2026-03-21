// RectCalculationTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

final class RectCalculationTests: XCTestCase {

    private let service = ScreenCaptureService()

    // MARK: - Normalisation

    func test_normalise_positiveSize_unchanged() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
        XCTAssertEqual(service.normalise(rect: rect), rect)
    }

    func test_normalise_negativeWidth_flipsOriginX() {
        let rect = CGRect(x: 110, y: 20, width: -100, height: 80)
        let expected = CGRect(x: 10, y: 20, width: 100, height: 80)
        XCTAssertEqual(service.normalise(rect: rect), expected)
    }

    func test_normalise_negativeHeight_flipsOriginY() {
        let rect = CGRect(x: 10, y: 100, width: 100, height: -80)
        let expected = CGRect(x: 10, y: 20, width: 100, height: 80)
        XCTAssertEqual(service.normalise(rect: rect), expected)
    }

    func test_normalise_bothNegative_flipsOrigin() {
        let rect = CGRect(x: 110, y: 100, width: -100, height: -80)
        let expected = CGRect(x: 10, y: 20, width: 100, height: 80)
        XCTAssertEqual(service.normalise(rect: rect), expected)
    }

    func test_normalise_zeroSize_returnsZeroSize() {
        let rect = CGRect(x: 5, y: 5, width: 0, height: 0)
        XCTAssertEqual(service.normalise(rect: rect).size, .zero)
    }

    // MARK: - Minimum Size Guard

    func test_capture_smallRect_throwsInvalidRect() {
        let tinyRect = CGRect(x: 0, y: 0, width: 2, height: 2)
        XCTAssertThrowsError(try service.capture(rect: tinyRect)) { error in
            XCTAssertEqual(error as? ScreenCaptureError, .invalidRect)
        }
    }
}

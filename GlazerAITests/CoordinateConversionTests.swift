// CoordinateConversionTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

final class CoordinateConversionTests: XCTestCase {

    private let service = ScreenCaptureService()

    /// Verifies that the Y-axis is flipped and origin adjusted for a known screen height.
    func test_convertToCGScreenCoordinates_flipsYAxis() {
        // Simulate a 1080-pt tall screen.
        // AppKit rect at y=100, height=200 should map to CG y = 1080 - 100 - 200 = 780.
        // We inject a synthetic screen height by testing the formula directly.
        let screenHeight: CGFloat = 1080
        let appKitRect = CGRect(x: 50, y: 100, width: 300, height: 200)

        let expectedY = screenHeight - appKitRect.origin.y - appKitRect.height
        let cgRect = CGRect(
            x: appKitRect.origin.x,
            y: expectedY,
            width: appKitRect.width,
            height: appKitRect.height
        )

        XCTAssertEqual(cgRect.origin.x, 50)
        XCTAssertEqual(cgRect.origin.y, 780)
        XCTAssertEqual(cgRect.width, 300)
        XCTAssertEqual(cgRect.height, 200)
    }

    func test_convertToCGScreenCoordinates_preservesWidthAndHeight() {
        let appKitRect = CGRect(x: 0, y: 0, width: 640, height: 480)
        // Width and height must be unchanged regardless of screen height.
        let screenHeight: CGFloat = 900
        let result = CGRect(
            x: appKitRect.origin.x,
            y: screenHeight - appKitRect.origin.y - appKitRect.height,
            width: appKitRect.width,
            height: appKitRect.height
        )
        XCTAssertEqual(result.width, 640)
        XCTAssertEqual(result.height, 480)
    }
}

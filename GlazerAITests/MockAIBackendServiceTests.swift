// MockAIBackendServiceTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

final class MockAIBackendServiceTests: XCTestCase {

    private var service: MockAIBackendService?

    override func setUp() {
        super.setUp()
        service = MockAIBackendService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Error Path

    func test_send_emptyData_throwsEmptyPayload() async {
        do {
            try await service?.send(image: Data())
            XCTFail("Expected AIBackendError.emptyPayload to be thrown")
        } catch AIBackendError.emptyPayload {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Success Path

    func test_send_nonEmptyData_doesNotThrow() async throws {
        let fakeImage = Data([0xFF, 0xD8, 0xFF]) // fake PNG header bytes
        // Should not throw; MockAIBackendService shows an alert on main thread
        // which is suppressed in test environments (no run loop modal).
        // We just verify no error is thrown.
        try await service?.send(image: fakeImage)
    }
}

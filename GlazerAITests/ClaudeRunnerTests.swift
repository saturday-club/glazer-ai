// ClaudeRunnerTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

@MainActor
final class ClaudeRunnerTests: XCTestCase {

    override func tearDown() async throws {
        // Restore any path the app host may have set between tests.
        CLIEnvironment.shared.resetForTesting()
    }

    func test_run_withoutCLIPath_throwsNotFound() async {
        CLIEnvironment.shared.resetForTesting()
        let runner = ClaudeRunner()

        do {
            _ = try await runner.run(prompt: "test")
            XCTFail("Expected ClaudeError.notFound")
        } catch ClaudeError.notFound {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_claudeError_notFound_hasDescription() {
        let error = ClaudeError.notFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Claude CLI") == true)
    }

    func test_claudeError_timeout_hasDescription() {
        let error = ClaudeError.timeout
        XCTAssertTrue(error.errorDescription?.contains("60 seconds") == true)
    }

    func test_claudeError_executionFailed_includesStderr() {
        let error = ClaudeError.executionFailed(stderr: "auth error")
        XCTAssertTrue(error.errorDescription?.contains("auth error") == true)
    }

    func test_claudeError_executionFailed_emptyStderr_showsUnknown() {
        let error = ClaudeError.executionFailed(stderr: "")
        XCTAssertTrue(error.errorDescription?.contains("Unknown error") == true)
    }
}

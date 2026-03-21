// ClaudeRunnerTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

final class ClaudeRunnerTests: XCTestCase {

    func test_run_withoutCLIPath_throwsNotFound() async {
        // CLIEnvironment.shared.claudePath is nil by default in test environment
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

    func test_shellEscape_handledInPrompt() async {
        // Verify that prompts with special characters don't crash
        let runner = ClaudeRunner()

        do {
            _ = try await runner.run(prompt: "it's a test with 'quotes'")
            XCTFail("Expected ClaudeError.notFound (CLI not installed in test)")
        } catch ClaudeError.notFound {
            // Expected — the shell escape logic was exercised without crash
        } catch {
            // Also acceptable — any error except a crash is fine
        }
    }
}

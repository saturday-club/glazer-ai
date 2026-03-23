// ResultsViewModelTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

@MainActor
final class ResultsViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// A minimal ClaudeResponse with a named profile.
    private func makeSuccessResponse(name: String = "Jane Doe") -> ClaudeResponse {
        ClaudeResponse(
            status: .success,
            profile: ProfileData(
                name: name,
                headline: "Engineer",
                company: "Acme",
                location: "SF",
                connections: "500+",
                about: "About text",
                experience: ["Acme — Engineer"],
                education: ["MIT"],
                skills: ["Swift", "iOS"]
            ),
            summary: "A great engineer.",
            message: nil
        )
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        let viewModel = ResultsViewModel()
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertNil(viewModel.claudeResponse)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Success State

    func test_successState_exposesClaudeResponse() {
        let viewModel = ResultsViewModel()
        let response = makeSuccessResponse()
        viewModel.state = .success(response: response)

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.claudeResponse)
        XCTAssertEqual(viewModel.claudeResponse?.profile?.name, "Jane Doe")
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Error State

    func test_errorState_exposesMessage() {
        let viewModel = ResultsViewModel()
        viewModel.state = .error(message: "Something failed")

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.claudeResponse)
        XCTAssertEqual(viewModel.errorMessage, "Something failed")
    }

    // MARK: - OCR Text

    func test_ocrText_defaultsToEmpty() {
        let viewModel = ResultsViewModel()
        XCTAssertTrue(viewModel.ocrText.isEmpty)
    }

    // MARK: - Copy Response

    func test_copyResponse_copiesFormattedTextToClipboard() {
        let viewModel = ResultsViewModel()
        viewModel.state = .success(response: makeSuccessResponse(name: "Jane Doe"))
        viewModel.copyResponse()

        let clipboard = NSPasteboard.general.string(forType: .string)
        XCTAssertNotNil(clipboard)
        XCTAssertTrue(clipboard?.contains("Jane Doe") == true)
    }

    func test_copyResponse_noResponse_doesNotCrash() {
        let viewModel = ResultsViewModel()
        // Loading state — no response; should be a no-op
        viewModel.copyResponse()
    }
}

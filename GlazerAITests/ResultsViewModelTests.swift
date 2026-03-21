// ResultsViewModelTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

@MainActor
final class ResultsViewModelTests: XCTestCase {

    func test_initialState_isLoading() {
        let viewModel = ResultsViewModel()
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertNil(viewModel.responseText)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_successState_exposesResponse() {
        let viewModel = ResultsViewModel()
        viewModel.state = .success(response: "Test response")

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.responseText, "Test response")
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_errorState_exposesMessage() {
        let viewModel = ResultsViewModel()
        viewModel.state = .error(message: "Something failed")

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.responseText)
        XCTAssertEqual(viewModel.errorMessage, "Something failed")
    }

    func test_ocrText_defaultsToEmpty() {
        let viewModel = ResultsViewModel()
        XCTAssertTrue(viewModel.ocrText.isEmpty)
    }

    func test_copyResponse_copiesTextToClipboard() {
        let viewModel = ResultsViewModel()
        viewModel.state = .success(response: "Copy me")
        viewModel.copyResponse()

        let clipboard = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboard, "Copy me")
    }

    func test_copyResponse_noResponse_doesNothing() {
        let viewModel = ResultsViewModel()
        // Loading state — no response
        viewModel.copyResponse()
        // No crash — pass
    }
}

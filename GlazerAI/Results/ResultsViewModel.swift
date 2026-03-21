// ResultsViewModel.swift
// GlazerAI
//
// Observable state for the results window. Tracks pipeline progress
// from loading through success or error.

import AppKit
import Foundation

/// Represents the current state of the results pipeline.
enum ResultsState: Sendable {
    /// Pipeline is running; show a spinner.
    case loading
    /// Pipeline completed successfully.
    case success(response: String)
    /// Pipeline failed with an error.
    case error(message: String)
}

/// View model for ``ResultsView``. Published properties drive the SwiftUI layout.
@MainActor
@Observable
final class ResultsViewModel {

    // MARK: - Published State

    /// Current pipeline state.
    var state: ResultsState = .loading

    /// Thumbnail of the snipped image.
    var snipImage: NSImage?

    /// Raw OCR text extracted from the image.
    var ocrText: String = ""

    /// Whether the OCR disclosure group is expanded.
    var isOCRExpanded: Bool = false

    // MARK: - Computed

    /// The Claude response text, if available.
    var responseText: String? {
        if case .success(let response) = state {
            return response
        }
        return nil
    }

    /// Whether the pipeline is still running.
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    /// Error message, if any.
    var errorMessage: String? {
        if case .error(let message) = state {
            return message
        }
        return nil
    }

    // MARK: - Actions

    /// Copies the Claude response to the clipboard.
    func copyResponse() {
        guard let text = responseText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

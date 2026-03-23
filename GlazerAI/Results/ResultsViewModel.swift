// ResultsViewModel.swift
// GlazerAI
//
// Observable state for the results window. Tracks pipeline progress
// from loading through success (structured ClaudeResponse) or error.

import AppKit
import Foundation

/// Represents the current state of the results pipeline.
enum ResultsState: Sendable {
    /// Pipeline is running; show a spinner.
    case loading
    /// Pipeline completed successfully with a parsed ClaudeResponse.
    case success(response: ClaudeResponse)
    /// Pipeline failed with an error message.
    case error(message: String)
}

@MainActor
protocol ResultsViewModelDelegate: AnyObject {
    func resultsViewModel(_ vm: ResultsViewModel, didRequestRefinementWith jobDescription: String)
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

    /// Job description text for tailoring the ice-breaker note.
    var jobDescription: String = ""

    /// Delegate notified when the user requests a refinement.
    weak var delegate: ResultsViewModelDelegate?

    // MARK: - Computed

    /// The parsed Claude response, if available.
    var claudeResponse: ClaudeResponse? {
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

    /// Requests a job-description-tailored ice-breaker note via the delegate.
    func requestRefinement() {
        guard !jobDescription.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        delegate?.resultsViewModel(self, didRequestRefinementWith: jobDescription)
    }

    /// Called by coordinator after refinement completes — patches the ice-breaker note.
    func applyRefinedNote(_ note: String) {
        guard case .success(let response) = state else { return }
        let patched = ClaudeResponse(
            status: response.status,
            profile: response.profile,
            research: response.research,
            iceBreakerNote: note,
            summary: response.summary,
            message: response.message
        )
        state = .success(response: patched)
    }

    /// Copies the ice-breaker note to the clipboard.
    func copyIceBreakerNote() {
        guard let note = claudeResponse?.iceBreakerNote else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note, forType: .string)
    }

    /// Copies a formatted summary of the profile to the clipboard.
    func copyResponse() {
        guard let resp = claudeResponse, let profile = resp.profile else { return }
        let text = formatProfileForClipboard(profile, summary: resp.summary)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Private

    private func formatProfileForClipboard(_ profile: ProfileData, summary: String?) -> String {
        var lines: [String] = []
        if let name = profile.name { lines.append("Name: \(name)") }
        if let headline = profile.headline { lines.append("Headline: \(headline)") }
        if let company = profile.company { lines.append("Company: \(company)") }
        if let location = profile.location { lines.append("Location: \(location)") }
        if let connections = profile.connections { lines.append("Connections: \(connections)") }
        if let about = profile.about { lines.append("\nAbout:\n\(about)") }
        if let experience = profile.experience, !experience.isEmpty {
            lines.append("\nExperience:")
            experience.forEach { lines.append("  • \($0)") }
        }
        if let education = profile.education, !education.isEmpty {
            lines.append("\nEducation:")
            education.forEach { lines.append("  • \($0)") }
        }
        if let skills = profile.skills, !skills.isEmpty {
            lines.append("\nSkills: \(skills.joined(separator: ", "))")
        }
        if let summary {
            lines.append("\nSummary:\n\(summary)")
        }
        return lines.joined(separator: "\n")
    }
}

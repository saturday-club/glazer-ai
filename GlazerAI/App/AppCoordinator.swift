// AppCoordinator.swift
// GlazerAI
//
// Central coordinator that wires together all subsystems:
// menu bar, snipping overlay, screen capture, OCR, prompt assembly,
// Claude CLI invocation, and results window.

import AppKit
import Foundation
import ScreenCaptureKit

/// Owns and coordinates all major Glazer AI subsystems.
@MainActor
final class AppCoordinator {

    // MARK: - Dependencies

    private let menuBarController: MenuBarController
    private let snippingWindowController: SnippingWindowController
    private let captureService: ScreenCaptureService
    private let ocrService: OCRService
    private let promptAssembler: PromptAssembler
    private let claudeRunner: ClaudeRunner
    private var settingsController: SettingsWindowController?
    private var historyController: HistoryWindowController?
    private var isShowingProfileSetupAlert = false

    /// Keeps strong references to results windows so they stay alive.
    private var resultsControllers: [ResultsWindowController] = []

    /// The sender's professional profile, used to personalise ice-breaker notes.
    private var candidateProfile: CandidateProfile = .load()

    // MARK: - Init

    init() {
        self.menuBarController        = MenuBarController()
        self.snippingWindowController = SnippingWindowController()
        self.captureService           = ScreenCaptureService()
        self.ocrService               = OCRService()
        self.promptAssembler          = PromptAssembler()
        self.claudeRunner             = ClaudeRunner()
        wire()
        performLaunchChecks()
    }

    // MARK: - Public API

    /// Activates the snipping overlay, or prompts for profile setup if not configured.
    func startCapture() {
        guard candidateProfile.isConfigured else {
            promptForProfileSetup()
            return
        }
        snippingWindowController.present()
    }

    private func promptForProfileSetup() {
        guard !isShowingProfileSetupAlert else {
            // Alert already visible — if settings window is open, just focus it.
            settingsController?.present()
            return
        }
        isShowingProfileSetupAlert = true
        let alert = NSAlert()
        alert.messageText = "Upload Your Resume First"
        alert.informativeText = "GlazerAI needs your resume to personalise ice-breaker " +
                                "messages. Upload a PDF in Settings to get started."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        isShowingProfileSetupAlert = false
        if response == .alertFirstButtonReturn {
            openSettings()
        }
    }

    // MARK: - Private

    private func wire() {
        menuBarController.delegate        = self
        snippingWindowController.delegate = self
    }

    private func performLaunchChecks() {
        requestPermissionsOnLaunch()
        checkClaudeCLI()
    }

    private func requestPermissionsOnLaunch() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        Task.detached {
            _ = try? await SCShareableContent.current
            _ = await MainActor.run { NSApp.setActivationPolicy(.accessory) }
        }
    }

    private func checkClaudeCLI() {
        Task {
            await CLIEnvironment.shared.resolve()
        }
    }

    // MARK: - History

    private func openHistory() {
        if historyController == nil {
            historyController = HistoryWindowController()
        }
        historyController?.present()
    }

    // MARK: - Settings

    private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController { [weak self] saved in
                self?.candidateProfile = saved
                debugLog("Candidate profile saved: \(saved.name)")
            }
        }
        settingsController?.present()
    }

    // MARK: - Pipeline

    /// Runs the full pipeline: capture → OCR → prompt → claude → results.
    private func runPipeline(rect: CGRect) {
        let profile = candidateProfile
        Task {
            do {
                let imageData = try await captureService.capture(rect: rect)
                debugCopyToClipboard(imageData)

                guard let ocrText = try await performOCR(on: imageData) else { return }

                let results = openResultsWindow(imageData: imageData, ocrText: ocrText)
                let claudeResponse = try await runClaude(ocrText: ocrText, candidate: profile)
                apply(response: claudeResponse, to: results, ocrText: ocrText, imageData: imageData)

            } catch {
                debugLog("Pipeline error: \(error.localizedDescription)", tag: "Error")
                showAlert(message: "GlazerAI Error", detail: error.localizedDescription)
            }
        }
    }

    /// Returns OCR text or nil if no text was found (alert shown).
    private func performOCR(on imageData: Data) async throws -> String? {
        do {
            return try await ocrService.recognizeText(in: imageData)
        } catch OCRError.noTextFound {
            showAlert(
                message: "No Text Found",
                detail: "The snipped region does not appear to contain text " +
                        "representing a LinkedIn profile."
            )
            return nil
        }
    }

    /// Opens the results window and sets thumbnail + OCR text.
    private func openResultsWindow(imageData: Data, ocrText: String) -> ResultsWindowController {
        let results = ResultsWindowController()
        resultsControllers.append(results)
        results.viewModel.snipImage = NSImage(data: imageData)
        results.viewModel.ocrText = ocrText
        results.viewModel.delegate = self
        results.show()
        return results
    }

    /// Assembles the prompt, calls Claude, and parses the JSON response.
    private func runClaude(ocrText: String, candidate: CandidateProfile) async throws -> ClaudeResponse {
        let prompt = promptAssembler.assemble(ocrText: ocrText, candidateProfile: candidate)
        debugLog("Prompt assembled (\(prompt.count) chars)", tag: "Claude")
        debugLog("--- PROMPT START ---\n\(prompt)\n--- PROMPT END ---", tag: "Claude")
        let raw = try await claudeRunner.run(prompt: prompt)
        debugLog("Raw response (\(raw.count) chars)", tag: "Claude")
        debugLog("--- RESPONSE START ---\n\(raw)\n--- RESPONSE END ---", tag: "Claude")
        return try ClaudeResponse.parse(from: raw)
    }

    /// Applies the parsed ClaudeResponse to the results window.
    private func apply(
        response: ClaudeResponse,
        to results: ResultsWindowController,
        ocrText: String,
        imageData: Data
    ) {
        switch response.status {
        case .noProfileFound:
            results.close()
            showAlert(
                message: "No LinkedIn Profile Found",
                detail: response.message ??
                        "The captured text does not appear to contain a LinkedIn profile."
            )
        case .success:
            results.viewModel.state = .success(response: response)
            saveGlaze(response: response, ocrText: ocrText, imageData: imageData)
        }
    }

    private func saveGlaze(response: ClaudeResponse, ocrText: String, imageData: Data) {
        var record = GlazeRecord.make(response: response, ocrText: ocrText, imageData: imageData)
        do {
            try GlazeStore.shared.insert(&record)
        } catch {
            debugLog("Failed to save glaze: \(error)", tag: "Error")
        }
    }

    private func debugCopyToClipboard(_ imageData: Data) {
        #if DEBUG
        if let nsImage = NSImage(data: imageData) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([nsImage])
            debugLog("Captured image copied to clipboard", tag: "Debug")
        }
        #endif
    }

    private func showAlert(message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - ResultsViewModelDelegate

extension AppCoordinator: ResultsViewModelDelegate {

    func resultsViewModel(_ vm: ResultsViewModel, didRequestRefinementWith jobDescription: String) {
        guard let response = vm.claudeResponse else { return }
        let profile = candidateProfile
        Task {
            do {
                let prompt = promptAssembler.assembleRefinement(
                    response: response,
                    jobDescription: jobDescription,
                    candidateProfile: profile
                )
                debugLog("Refinement prompt assembled (\(prompt.count) chars)", tag: "Claude")
                let raw = try await claudeRunner.run(prompt: prompt)
                let refined = try ClaudeResponse.parse(from: raw)
                if let note = refined.iceBreakerNote {
                    vm.applyRefinedNote(note)
                    updateStoredNote(note, jobDescription: jobDescription, for: vm)
                }
            } catch {
                debugLog("Refinement error: \(error.localizedDescription)", tag: "Error")
            }
        }
    }

    private func updateStoredNote(_ note: String, jobDescription: String, for vm: ResultsViewModel) {
        guard let allRecords = try? GlazeStore.shared.fetchAll(),
              let record = allRecords.first(where: { $0.ocrText == vm.ocrText }) else { return }
        var updated = record
        updated.tailoredNote = note
        updated.jobDescription = jobDescription
        try? GlazeStore.shared.update(updated)
    }
}

// MARK: - MenuBarControllerDelegate

extension AppCoordinator: MenuBarControllerDelegate {

    func menuBarControllerDidRequestCapture(_ controller: MenuBarController) {
        startCapture()
    }

    func menuBarControllerDidRequestHistory(_ controller: MenuBarController) {
        openHistory()
    }

    func menuBarControllerDidRequestSettings(_ controller: MenuBarController) {
        openSettings()
    }
}

// MARK: - SnippingWindowControllerDelegate

extension AppCoordinator: SnippingWindowControllerDelegate {

    func snippingWindowController(
        _ controller: SnippingWindowController,
        didCaptureRect rect: CGRect
    ) {
        runPipeline(rect: rect)
    }

    func snippingWindowControllerDidCancel(_ controller: SnippingWindowController) {
        // No-op.
    }
}

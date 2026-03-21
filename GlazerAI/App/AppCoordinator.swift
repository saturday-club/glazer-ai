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

    /// Keeps strong references to results windows so they stay alive.
    private var resultsControllers: [ResultsWindowController] = []

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

    /// Activates the snipping overlay.
    func startCapture() {
        snippingWindowController.present()
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
        // LSUIElement apps run as .accessory (background-only). macOS suppresses TCC
        // permission dialogs for background apps. We temporarily surface the app as a
        // regular app so the Screen Recording prompt is shown, then immediately hide it.
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

    /// Runs the full pipeline: capture → OCR → prompt → claude → results.
    private func runPipeline(rect: CGRect) {
        let results = ResultsWindowController()
        resultsControllers.append(results)
        results.show()

        Task {
            do {
                // Step 1: Capture
                let imageData = try await captureService.capture(rect: rect)

                #if DEBUG
                if let nsImage = NSImage(data: imageData) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([nsImage])
                    print("[DEBUG] Captured image copied to clipboard")
                }
                #endif

                // Set thumbnail
                results.viewModel.snipImage = NSImage(data: imageData)

                // Step 2: OCR
                let ocrText = try await ocrService.recognizeText(in: imageData)
                results.viewModel.ocrText = ocrText

                // Step 3: Assemble prompt
                let prompt = promptAssembler.assemble(ocrText: ocrText)
                print("[Glazer AI] Prompt assembled (\(prompt.count) chars)")

                // Step 4: Run Claude
                let response = try await claudeRunner.run(prompt: prompt)
                results.viewModel.state = .success(response: response)

            } catch {
                results.viewModel.state = .error(message: error.localizedDescription)
                print("[Glazer AI] Pipeline error: \(error.localizedDescription)")
            }
        }
    }

    private func handleCaptureError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Glazer AI"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - MenuBarControllerDelegate

extension AppCoordinator: MenuBarControllerDelegate {

    func menuBarControllerDidRequestCapture(_ controller: MenuBarController) {
        startCapture()
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

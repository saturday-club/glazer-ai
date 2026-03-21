// AppCoordinator.swift
// GlazerAI
//
// Central coordinator that wires together all subsystems:
// menu bar, snipping overlay, screen capture, and AI backend.

import AppKit
import Foundation
import ScreenCaptureKit

/// Owns and coordinates all major Glazer AI subsystems.
@available(macOS 14.0, *)
@MainActor
final class AppCoordinator {

    // MARK: - Dependencies

    private let menuBarController: MenuBarController
    private let snippingWindowController: SnippingWindowController
    private let captureService: ScreenCaptureService
    private let backendService: AIBackendService
    private let settingsWindowController: SettingsWindowController

    // MARK: - Init

    init(backendService: AIBackendService = MockAIBackendService()) {
        self.backendService           = backendService
        self.menuBarController        = MenuBarController()
        self.snippingWindowController = SnippingWindowController()
        self.captureService           = ScreenCaptureService()
        self.settingsWindowController = SettingsWindowController(onSave: { _ in })

        wire()
        requestPermissionsOnLaunch()
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

    private func requestPermissionsOnLaunch() {
        // LSUIElement apps run as .accessory (background-only). macOS suppresses TCC
        // permission dialogs for background apps. We temporarily surface the app as a
        // regular app so the Screen Recording prompt is shown, then immediately hide it.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        Task.detached {
            // SCShareableContent.current registers the app with TCC and shows
            // the native Screen Recording permission dialog on first launch.
            _ = try? await SCShareableContent.current

            await MainActor.run { NSApp.setActivationPolicy(.accessory) }
        }
    }

    private func handleCaptureError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Capture Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - MenuBarControllerDelegate

@available(macOS 14.0, *)
extension AppCoordinator: MenuBarControllerDelegate {

    func menuBarControllerDidRequestCapture(_ controller: MenuBarController) {
        startCapture()
    }

    func menuBarControllerDidRequestSettings(_ controller: MenuBarController) {
        settingsWindowController.present()
    }
}

// MARK: - SnippingWindowControllerDelegate

@available(macOS 14.0, *)
extension AppCoordinator: SnippingWindowControllerDelegate {

    func snippingWindowController(
        _ controller: SnippingWindowController,
        didCaptureRect rect: CGRect
    ) {
        Task {
            do {
                let imageData = try await captureService.capture(rect: rect)
                try await backendService.send(image: imageData)
            } catch {
                handleCaptureError(error)
            }
        }
    }

    func snippingWindowControllerDidCancel(_ controller: SnippingWindowController) {
        // No-op.
    }
}

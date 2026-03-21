// MockAIBackendService.swift
// GlazerAI
//
// Stub implementation of AIBackendService used during development.
// swiftlint:disable:next todo
// TODO: Replace MockAIBackendService with a real backend (HTTP upload, local model, etc.)

import AppKit
import Foundation

/// Development stub that logs the captured image size and shows a success alert.
///
/// Replace this with a concrete backend implementation that conforms to
/// ``AIBackendService`` and inject it into ``AppCoordinator``.
@MainActor
final class MockAIBackendService: AIBackendService {

    // MARK: - AIBackendService

    /// Validates the payload, logs its size, and presents a success `NSAlert`.
    ///
    /// - Parameter image: Raw PNG `Data` of the captured screen region.
    /// - Throws: ``AIBackendError/emptyPayload`` when `image` is empty.
    func send(image: Data) async throws {
        guard !image.isEmpty else {
            throw AIBackendError.emptyPayload
        }

        print("[Glazer AI] Captured \(image.count) bytes")

        #if DEBUG
        // Copy the captured image to the clipboard so it can be inspected by pasting.
        if let nsImage = NSImage(data: image) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([nsImage])
            print("[DEBUG] Captured image copied to clipboard — paste anywhere to verify.")
        }
        #endif

        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Capture Sent"
            alert.informativeText = "Image size: \(image.count) bytes"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

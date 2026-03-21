// SnippingWindowController.swift
// GlazerAI
//
// Presents and manages the full-screen transparent overlay window used for
// region selection. Delegates selection results back to AppCoordinator.

import AppKit
import Foundation

// MARK: - Delegate

/// Receives the outcome of a snipping session.
@MainActor
protocol SnippingWindowControllerDelegate: AnyObject {
    /// Called with the confirmed selection rectangle in screen coordinates.
    func snippingWindowController(
        _ controller: SnippingWindowController,
        didCaptureRect rect: CGRect
    )
    /// Called when the user cancels without making a selection.
    func snippingWindowControllerDidCancel(_ controller: SnippingWindowController)
}

// MARK: - Controller

/// Manages the full-screen overlay window for region selection.
final class SnippingWindowController: NSWindowController {

    // MARK: - Properties

    /// Notified when the user confirms or cancels a selection.
    weak var delegate: SnippingWindowControllerDelegate?

    private let snippingView: SnippingView

    // MARK: - Init

    /// Creates the overlay window covering the main screen.
    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let snippingView = SnippingView(frame: screen.frame)

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.contentView = snippingView
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.snippingView = snippingView
        super.init(window: window)

        snippingView.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported — use init()")
    }

    // MARK: - Public API

    /// Presents the overlay and installs the crosshair cursor.
    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(snippingView)
        NSCursor.crosshair.push()
    }

    /// Dismisses the overlay and restores the default cursor.
    func dismiss() {
        NSCursor.pop()
        close()
    }
}

// MARK: - SnippingViewDelegate

extension SnippingWindowController: SnippingViewDelegate {

    func snippingView(_ view: SnippingView, didConfirmRect rect: CGRect) {
        // Convert from window-local (AppKit, bottom-left origin) to screen coordinates.
        let screenRect = window?.convertToScreen(rect) ?? rect
        dismiss()
        delegate?.snippingWindowController(self, didCaptureRect: screenRect)
    }

    func snippingViewDidCancel(_ view: SnippingView) {
        dismiss()
        delegate?.snippingWindowControllerDidCancel(self)
    }
}

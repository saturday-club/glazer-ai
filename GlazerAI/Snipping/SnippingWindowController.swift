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

// MARK: - SnippingWindow

/// Borderless NSWindow subclass that opts into key-window status.
/// By default, borderless windows return false for canBecomeKey, which
/// prevents them from ever receiving keyboard events.
private final class SnippingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Controller

/// Manages the full-screen overlay window for region selection.
final class SnippingWindowController: NSWindowController {

    // MARK: - Properties

    /// Notified when the user confirms or cancels a selection.
    weak var delegate: SnippingWindowControllerDelegate?

    private let snippingView: SnippingView

    /// Local event monitor for Escape — catches keyDown before AppKit routing.
    private var escapeMonitor: Any?

    // MARK: - Init

    /// Creates the overlay window covering the main screen.
    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let snippingView = SnippingView(frame: screen.frame)

        let window = SnippingWindow(
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

    /// Presents the overlay with a clean slate, stealing focus from the frontmost app.
    func present() {
        snippingView.reset()
        // Activate this process so the overlay can become the key window.
        // Without this, LSUIElement background apps can't steal focus.
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(snippingView)
        NSCursor.crosshair.push()
        installEscapeMonitor()
    }

    /// Dismisses the overlay and restores the default cursor.
    func dismiss() {
        removeEscapeMonitor()
        NSCursor.pop()
        close()
    }

    // MARK: - Private

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.cancel()
                return nil // consume the event
            }
            return event
        }
    }

    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    private func cancel() {
        dismiss()
        delegate?.snippingWindowControllerDidCancel(self)
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
        cancel()
    }
}

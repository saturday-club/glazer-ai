// ResultsWindowController.swift
// GlazerAI
//
// Manages an NSWindow that hosts the SwiftUI ResultsView.
// Each capture opens a new results window.

import AppKit
import SwiftUI

/// Presents a results window for a single capture pipeline run.
@MainActor
final class ResultsWindowController {

    // MARK: - Properties

    /// The view model driving the results view.
    let viewModel: ResultsViewModel

    /// The managed window. Retained to prevent deallocation.
    private var window: NSWindow?

    // MARK: - Init

    /// Creates a results controller with a fresh view model.
    init() {
        self.viewModel = ResultsViewModel()
    }

    // MARK: - Public API

    /// Opens the results window.
    func show() {
        let hostingView = NSHostingView(rootView: ResultsView(viewModel: viewModel))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "GlazerAI \u{2014} Results"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.window = window

        // Bring the app to front so the results window is visible
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes the results window if it is open.
    func close() {
        window?.close()
        window = nil
    }
}

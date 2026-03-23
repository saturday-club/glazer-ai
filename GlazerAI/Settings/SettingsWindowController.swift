// SettingsWindowController.swift
// GlazerAI
//
// Wraps SettingsView in an NSWindowController. Loads the saved
// CandidateProfile on open and persists it on save.

import AppKit
import SwiftUI

/// Presents the candidate profile settings panel.
final class SettingsWindowController: NSWindowController {

    // MARK: - Init

    init(onSave: @escaping (CandidateProfile) -> Void) {
        let relay = ActionRelay()
        let profile = CandidateProfile.load()

        let settingsView = SettingsView(
            profile: profile,
            onSave: { saved in
                saved.save()
                onSave(saved)
                relay.action?()
            },
            onCancel: {
                relay.action?()
            }
        )

        let hosting = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "GlazerAI Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        relay.action = { [weak self] in self?.close() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Public API

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Helpers

private final class ActionRelay {
    var action: (() -> Void)?
}

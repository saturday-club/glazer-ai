// SettingsWindowController.swift
// GlazerAI
//
// Wraps the SwiftUI SettingsView in an NSWindowController so it can be
// presented as a floating panel from the menu bar.

import AppKit
import SwiftUI

/// Presents and manages the Glazer AI settings panel.
final class SettingsWindowController: NSWindowController {

    // MARK: - Init

    /// Creates the settings window hosting a ``SettingsView``.
    ///
    /// - Parameter onSave: Called with the new shortcut string when the user taps Save.
    init(onSave: @escaping (String) -> Void) {
        // Use a relay so we can reference `self` after super.init.
        let relay = ActionRelay()

        let settingsView = SettingsView(
            onSave: { shortcut in
                onSave(shortcut)
                relay.action?()
            },
            onCancel: {
                relay.action?()
            }
        )

        let hosting = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Glazer AI Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        // Wire close action now that self is available.
        relay.action = { [weak self] in self?.close() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported — use init(onSave:)")
    }

    // MARK: - Public API

    /// Shows the settings window and brings it to the front.
    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Helpers

/// Lightweight indirection that breaks the self-before-super-init cycle.
private final class ActionRelay {
    /// Closure set after `super.init` completes.
    var action: (() -> Void)?
}

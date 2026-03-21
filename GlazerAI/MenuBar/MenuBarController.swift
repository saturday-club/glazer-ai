// MenuBarController.swift
// GlazerAI
//
// Owns the NSStatusItem and builds the action menu.

import AppKit
import Foundation

// MARK: - Delegate

/// Handles actions triggered from the menu bar menu.
@MainActor
protocol MenuBarControllerDelegate: AnyObject {
    /// The user chose "Capture Region" from the menu (or triggered via shortcut).
    func menuBarControllerDidRequestCapture(_ controller: MenuBarController)
    /// The user chose "Settings…" from the menu.
    func menuBarControllerDidRequestSettings(_ controller: MenuBarController)
}

// MARK: - Controller

/// Creates and manages the `NSStatusItem` for Glazer AI.
@MainActor
final class MenuBarController {

    // MARK: - Properties

    /// Notified when the user selects a menu action.
    weak var delegate: MenuBarControllerDelegate?

    private let statusItem: NSStatusItem

    // MARK: - Init

    /// Installs the status item in the system menu bar.
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
        configureMenu()
    }

    // MARK: - Private

    private func configureButton() {
        guard let button = statusItem.button else { return }

        if let sfIcon = NSImage(systemSymbolName: Constants.menuBarSymbolName, accessibilityDescription: "Glazer AI") {
            sfIcon.isTemplate = true
            button.image = sfIcon
        } else if let bundledIcon = NSImage(named: "MenuBarIcon") {
            bundledIcon.isTemplate = true
            button.image = bundledIcon
        }

        button.toolTip = "Glazer AI — ⌘⇧2 to capture"
    }

    private func configureMenu() {
        let menu = NSMenu()

        let captureItem = NSMenuItem(
            title: "Capture Region",
            action: #selector(captureRegion),
            keyEquivalent: ""
        )
        captureItem.target = self
        menu.addItem(captureItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Quit Glazer AI",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func captureRegion() {
        delegate?.menuBarControllerDidRequestCapture(self)
    }

    @objc private func openSettings() {
        delegate?.menuBarControllerDidRequestSettings(self)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

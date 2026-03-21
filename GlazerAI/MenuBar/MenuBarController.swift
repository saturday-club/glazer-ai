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
    /// The user chose "Capture Region" from the menu.
    func menuBarControllerDidRequestCapture(_ controller: MenuBarController)
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

        let iconSize = NSSize(width: Constants.menuBarIconSize, height: Constants.menuBarIconSize)
        if let bundledIcon = NSImage(named: "MenuBarIcon") {
            bundledIcon.size = iconSize
            bundledIcon.isTemplate = true
            button.image = bundledIcon
        } else if let sfIcon = NSImage(systemSymbolName: Constants.menuBarSymbolName,
                                       accessibilityDescription: "Glazer AI") {
            sfIcon.size = iconSize
            sfIcon.isTemplate = true
            button.image = sfIcon
        }

        button.toolTip = "Glazer AI"
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

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MenuBarController.swift
// GlazerAI
//
// Owns the NSStatusItem.
// Left-click on icon → activate snipping.
// Right-click → minimal context menu (Settings, Quit).

import AppKit
import Foundation

// MARK: - Delegate

/// Handles actions triggered from the menu bar.
@MainActor
protocol MenuBarControllerDelegate: AnyObject {
    func menuBarControllerDidRequestCapture(_ controller: MenuBarController)
    func menuBarControllerDidRequestHistory(_ controller: MenuBarController)
    func menuBarControllerDidRequestSettings(_ controller: MenuBarController)
}

// MARK: - Controller

@MainActor
final class MenuBarController {

    weak var delegate: MenuBarControllerDelegate?

    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
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
                                       accessibilityDescription: "GlazerAI") {
            sfIcon.size = iconSize
            sfIcon.isTemplate = true
            button.image = sfIcon
        }

        button.toolTip = "GlazerAI — Click to snip"
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
        } else {
            delegate?.menuBarControllerDidRequestCapture(self)
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let historyItem = NSMenuItem(title: "History\u{2026}", action: #selector(openHistory), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit GlazerAI", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil   // remove after shown so left-click still fires our action
    }

    @objc private func openHistory() {
        delegate?.menuBarControllerDidRequestHistory(self)
    }

    @objc private func openSettings() {
        delegate?.menuBarControllerDidRequestSettings(self)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

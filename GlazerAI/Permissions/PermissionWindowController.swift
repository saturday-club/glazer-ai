// PermissionWindowController.swift
// GlazerAI
//
// Hosts PermissionCheckView in a floating NSWindow.
// Shown by AppCoordinator when screen recording permission is missing at launch.

import AppKit
import SwiftUI

/// Presents the screen-recording permission dialog.
@MainActor
final class PermissionWindowController: NSWindowController {

    // MARK: - Init

    init(permissionService: ScreenRecordingPermissionService) {
        let relay = PermissionActionRelay()

        let view = PermissionCheckView(
            service: permissionService,
            onHide: { relay.triggerHide() },
            onQuit: { relay.triggerQuit() }
        )

        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Glazer AI — Screen Recording"
        window.styleMask = [.titled]
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating

        super.init(window: window)

        relay.hideAction = { [weak self] in self?.close() }
        relay.quitAction = { NSApplication.shared.terminate(nil) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported — use init(permissionService:)")
    }

    // MARK: - Public API

    /// Shows the window and brings it to the front.
    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Helpers

/// Lightweight indirection that breaks the self-before-super-init cycle.
private final class PermissionActionRelay {
    var hideAction: (() -> Void)?
    var quitAction: (() -> Void)?

    func triggerHide() { hideAction?() }
    func triggerQuit() { quitAction?() }
}

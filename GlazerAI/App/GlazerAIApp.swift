// GlazerAIApp.swift
// GlazerAI
//
// Application entry point. Boots the AppCoordinator and suppresses the
// default SwiftUI window so the app runs as a menu-bar-only agent.

import AppKit
import SwiftUI

@main
struct GlazerAIApp: App {

    // MARK: - AppDelegate Bridge

    /// Bridges to AppKit so we can control the activation policy.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // MARK: - Scene

    var body: some Scene {
        // No windows — the app lives entirely in the menu bar.
        Settings { EmptyView() }
    }
}

// MARK: - AppDelegate

/// AppKit delegate responsible for creating and holding ``AppCoordinator``.
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// The single coordinator instance for the lifetime of the app.
    @available(macOS 14.0, *)
    private var coordinator: AppCoordinator? {
        get { _coordinator as? AppCoordinator }
        set { _coordinator = newValue }
    }
    private var _coordinator: AnyObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Note: activation policy is set to .accessory inside AppCoordinator
        // after the permission prompt completes, so we do NOT set it here.
        if #available(macOS 14.0, *) {
            coordinator = AppCoordinator()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Prevent quitting when settings window closes.
        return false
    }
}

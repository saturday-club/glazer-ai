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
    private var coordinator: AppCoordinator?
    /// Debug console — allocated only when --debug is passed.
    private var debugConsole: DebugConsoleWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy FIRST, before anything else.
        // .accessory = menu bar app, no Dock icon, but can bring windows to front.
        // Must be set here, not in AppCoordinator. Matches AutoLog pattern.
        NSApp.setActivationPolicy(.accessory)

        if CommandLine.arguments.contains("--debug") {
            DebugLogger.shared.isEnabled = true
            let console = DebugConsoleWindowController()
            debugConsole = console
            console.present()
            debugLog("Debug mode enabled", tag: "App")
        }

        coordinator = AppCoordinator()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Prevent quitting when settings window closes.
        return false
    }
}

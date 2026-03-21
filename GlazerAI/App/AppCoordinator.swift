// AppCoordinator.swift
// GlazerAI
//
// Central coordinator that wires together all subsystems:
// menu bar, global hotkey, snipping overlay, screen capture, and AI backend.

import AppKit
import Foundation

/// Owns and coordinates all major Glazer AI subsystems.
///
/// Inject dependencies via the initialiser to enable unit testing.
@MainActor
final class AppCoordinator {

    // MARK: - Dependencies

    private let menuBarController: MenuBarController
    private let hotkeyManager: GlobalHotkeyManager
    private let snippingWindowController: SnippingWindowController
    private let captureService: ScreenCaptureService
    private let backendService: AIBackendService
    private let settingsWindowController: SettingsWindowController
    private let permissionService: ScreenRecordingPermissionService
    private var permissionWindowController: PermissionWindowController?

    // MARK: - Init

    /// Creates the coordinator with the given service implementations.
    ///
    /// - Parameters:
    ///   - backendService: The AI backend to receive captured images.
    ///     Defaults to ``MockAIBackendService``.
    init(backendService: AIBackendService = MockAIBackendService()) {
        self.backendService              = backendService
        self.menuBarController           = MenuBarController()
        self.hotkeyManager               = GlobalHotkeyManager()
        self.snippingWindowController    = SnippingWindowController()
        self.captureService              = ScreenCaptureService()
        self.settingsWindowController    = SettingsWindowController(onSave: { _ in })
        self.permissionService           = ScreenRecordingPermissionService()

        wire()
        checkPermissionOnLaunch()
    }

    // MARK: - Public API

    /// Activates the snipping overlay. Called by the menu item and global hotkey.
    func startCapture() {
        snippingWindowController.present()
    }

    // MARK: - Private

    private func wire() {
        menuBarController.delegate         = self
        snippingWindowController.delegate  = self

        let shortcut = loadShortcut()
        let registered = hotkeyManager.register(shortcut: shortcut) { [weak self] in
            MainActor.assumeIsolated {
                self?.startCapture()
            }
        }
        if !registered {
            promptForAccessibilityPermission()
        }
    }

    private func loadShortcut() -> KeyboardShortcut {
        guard let data     = UserDefaults.standard.data(forKey: Constants.shortcutDefaultsKey),
              let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
        else {
            return .defaultShortcut
        }
        return shortcut
    }

    private func saveShortcut(_ shortcut: KeyboardShortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        UserDefaults.standard.set(data, forKey: Constants.shortcutDefaultsKey)
    }

    private func promptForAccessibilityPermission() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            The global shortcut ⌘⇧2 requires Accessibility access so it fires \
            even when Glazer AI is in the background.

            Please grant access in System Settings → Privacy & Security → \
            Accessibility, then relaunch Glazer AI.
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func checkPermissionOnLaunch() {
        guard !permissionService.isGranted else { return }
        let controller = PermissionWindowController(permissionService: permissionService)
        permissionWindowController = controller
        controller.present()
    }

    private func handleCaptureError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Capture Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - MenuBarControllerDelegate

extension AppCoordinator: MenuBarControllerDelegate {

    func menuBarControllerDidRequestCapture(_ controller: MenuBarController) {
        startCapture()
    }

    func menuBarControllerDidRequestSettings(_ controller: MenuBarController) {
        settingsWindowController.present()
    }
}

// MARK: - SnippingWindowControllerDelegate

extension AppCoordinator: SnippingWindowControllerDelegate {

    func snippingWindowController(
        _ controller: SnippingWindowController,
        didCaptureRect rect: CGRect
    ) {
        Task {
            do {
                let imageData = try captureService.capture(rect: rect)
                try await backendService.send(image: imageData)
            } catch {
                handleCaptureError(error)
            }
        }
    }

    func snippingWindowControllerDidCancel(_ controller: SnippingWindowController) {
        // No-op: user cancelled, nothing to do.
    }
}

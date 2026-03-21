// ScreenRecordingPermissionService.swift
// GlazerAI
//
// Checks and requests macOS Screen Recording permission via CoreGraphics APIs.

import AppKit
import CoreGraphics
import Foundation

/// Checks and requests macOS Screen Recording permission.
final class ScreenRecordingPermissionService {

    // MARK: - Public API

    /// Returns `true` if the app currently has screen recording permission.
    var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system permission prompt (first time only) and opens
    /// System Settings > Privacy & Security > Screen Recording so the user
    /// can toggle the switch.
    func requestAccess() {
        CGRequestScreenCaptureAccess()
        openSystemSettings()
    }

    // MARK: - Private

    private func openSystemSettings() {
        // swiftlint:disable:next line_length
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

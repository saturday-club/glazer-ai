// Constants.swift
// GlazerAI
//
// App-wide named constants. Never use magic numbers or strings in production code —
// reference these instead.

import Foundation

/// App-wide named constants.
enum Constants {
    /// UserDefaults key for persisting the global keyboard shortcut.
    static let shortcutDefaultsKey = "globalShortcut"

    /// Default global shortcut expressed as a human-readable string for display.
    static let defaultShortcutDescription = "⌘⇧2"

    /// Opacity of the dim overlay covering the screen during snipping (0–1).
    static let overlayDimOpacity: Double = 0.4

    /// Width of the selection rectangle border in points.
    static let selectionBorderWidth: CGFloat = 1.0

    /// Blue accent colour used for the selection border (#007AFF).
    static let selectionBorderRed: CGFloat = 0.0
    static let selectionBorderGreen: CGFloat = 0.478
    static let selectionBorderBlue: CGFloat = 1.0

    /// Menu bar icon SF Symbol name.
    static let menuBarSymbolName = "circle.dashed"

    /// Menu bar icon size in points.
    static let menuBarIconSize: CGFloat = 18.0

    /// Minimum drag distance (points) before a selection is considered valid.
    static let minimumSelectionSize: CGFloat = 4.0
}

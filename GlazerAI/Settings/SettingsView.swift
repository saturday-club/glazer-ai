// SettingsView.swift
// GlazerAI
//
// SwiftUI form for configuring Glazer AI preferences.

import SwiftUI

/// The main settings form, presented inside ``SettingsWindowController``.
struct SettingsView: View {

    // MARK: - State

    /// Current shortcut description shown to the user (display only in v1).
    @State private var shortcutText: String = Constants.defaultShortcutDescription

    /// Callback invoked when the user taps Save.
    var onSave: (String) -> Void
    /// Callback invoked when the user taps Cancel.
    var onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Glazer AI Settings")
                .font(.headline)

            Divider()

            HStack {
                Text("Keyboard Shortcut")
                    .frame(width: 140, alignment: .leading)
                ShortcutRecorderView(shortcutText: $shortcutText)
                    .frame(width: 120)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(shortcutText) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320, height: 140)
    }
}

// ShortcutRecorderView.swift
// GlazerAI
//
// A SwiftUI-compatible key-combo recorder that captures the next key press
// and formats it as a human-readable shortcut string (e.g. "⌘⇧2").

import AppKit
import SwiftUI

// MARK: - NSViewRepresentable Wrapper

/// A key-combo recorder control bridged into SwiftUI.
///
/// Tap the field to begin recording; press a key combo to set it.
struct ShortcutRecorderView: NSViewRepresentable {

    /// Bound to the human-readable shortcut description (e.g. `"⌘⇧2"`).
    @Binding var shortcutText: String

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.shortcutText = shortcutText
        view.onChange = { newText in
            shortcutText = newText
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.shortcutText = shortcutText
    }
}

// MARK: - AppKit Implementation

/// AppKit text field subclass that captures the next key combo pressed while focused.
final class ShortcutRecorderNSView: NSTextField {

    // MARK: - Properties

    /// The human-readable shortcut string displayed in the field.
    var shortcutText: String = "" {
        didSet { stringValue = shortcutText }
    }

    /// Called with the new shortcut string whenever the user records a new combo.
    var onChange: ((String) -> Void)?

    private var isRecording = false

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        isEditable    = false
        isSelectable  = false
        isBezeled     = true
        bezelStyle    = .roundedBezel
        alignment     = .center
        placeholderString = "Click to record"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported — use init()")
    }

    // MARK: - Mouse / Key Handling

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        stringValue = "Recording…"
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        isRecording = false

        let recorded = format(event: event)
        shortcutText = recorded
        onChange?(recorded)
    }

    // MARK: - Formatting

    /// Converts a key event into a human-readable shortcut string.
    private func format(event: NSEvent) -> String {
        var result = ""
        let flags = event.modifierFlags

        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }

        result += event.charactersIgnoringModifiers?.uppercased() ?? "?"
        return result
    }
}

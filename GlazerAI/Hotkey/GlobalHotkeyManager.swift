// GlobalHotkeyManager.swift
// GlazerAI
//
// Registers and deregisters a global CGEvent tap so the snipping shortcut
// fires even when Glazer AI is not the frontmost application.
//
// CGEventTapCallBack is @convention(c) — it cannot capture Swift values.
// Context is passed via the `userInfo` UnsafeMutableRawPointer using a
// retained TapContext object, which is released on unregister/deinit.

import AppKit
import Carbon
import Foundation

// MARK: - Shortcut Model

/// A lightweight, codable representation of a keyboard shortcut.
struct KeyboardShortcut: Codable, Equatable, Sendable {
    /// The virtual key code (Carbon `kVK_*` constants).
    let keyCode: UInt16
    /// The modifier flags (Carbon `cmdKey`, `shiftKey`, etc.).
    let modifierFlags: UInt32

    /// The default shortcut: ⌘⇧2.
    static let defaultShortcut = KeyboardShortcut(
        keyCode: UInt16(kVK_ANSI_2),
        modifierFlags: UInt32(cmdKey | shiftKey)
    )
}

// MARK: - Tap Context

/// Holds the shortcut definition and fire action for the C-level event tap callback.
///
/// Marked `@unchecked Sendable` because the fire closure always dispatches
/// to the main queue before touching any non-Sendable state.
private final class TapContext: @unchecked Sendable {
    let shortcut: KeyboardShortcut
    /// Always dispatches to the main queue before calling the user handler.
    let fire: @Sendable () -> Void

    init(shortcut: KeyboardShortcut, fire: @Sendable @escaping () -> Void) {
        self.shortcut = shortcut
        self.fire = fire
    }
}

// MARK: - Manager

/// Manages registration of a global CGEvent tap for the user-configured shortcut.
///
/// All public methods must be called on the main thread.
final class GlobalHotkeyManager {

    // MARK: - Private State

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    /// Retained pointer passed as `userInfo` — released in `tearDownTap()`.
    private var contextPtr: Unmanaged<TapContext>?

    // MARK: - Init / Deinit

    /// Creates a new manager with no active shortcut.
    init() {}

    deinit {
        tearDownTap()
    }

    // MARK: - Public API

    /// Registers a global event tap for `shortcut`, replacing any previous binding.
    ///
    /// - Parameters:
    ///   - shortcut: The keyboard shortcut to monitor.
    ///   - handler: Closure invoked on the main thread when the shortcut fires.
    /// - Returns: `true` if registration succeeded; `false` if the event tap
    ///   could not be created (usually due to missing Accessibility permission).
    @discardableResult
    // swiftlint:disable:next function_body_length
    func register(shortcut: KeyboardShortcut, handler: @Sendable @escaping () -> Void) -> Bool {
        tearDownTap()

        // Build the context — the C callback accesses this via `userInfo`.
        let ctx = TapContext(shortcut: shortcut) {
            DispatchQueue.main.async { handler() }
        }
        let retained = Unmanaged.passRetained(ctx)
        contextPtr = retained

        // Pure C callback — no captures allowed.
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard type == .keyDown, let userInfo else {
                return Unmanaged.passRetained(event)
            }

            let ctx = Unmanaged<TapContext>.fromOpaque(userInfo).takeUnretainedValue()
            let shortcutDef = ctx.shortcut

            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            let wantsCmd   = (shortcutDef.modifierFlags & UInt32(cmdKey))     != 0
            let wantsShift = (shortcutDef.modifierFlags & UInt32(shiftKey))   != 0
            let wantsOpt   = (shortcutDef.modifierFlags & UInt32(optionKey))  != 0
            let wantsCtrl  = (shortcutDef.modifierFlags & UInt32(controlKey)) != 0

            guard keyCode == shortcutDef.keyCode,
                  flags.contains(.maskCommand)   == wantsCmd,
                  flags.contains(.maskShift)     == wantsShift,
                  flags.contains(.maskAlternate) == wantsOpt,
                  flags.contains(.maskControl)   == wantsCtrl else {
                return Unmanaged.passRetained(event)
            }

            ctx.fire()
            return Unmanaged.passRetained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback,
            userInfo: retained.toOpaque()
        ) else {
            retained.release()
            contextPtr = nil
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    /// Removes the active event tap and clears the stored shortcut and handler.
    func unregister() {
        tearDownTap()
    }

    /// Returns `true` if an event tap is currently active.
    var isRegistered: Bool { eventTap != nil }

    // MARK: - Private

    private func tearDownTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        contextPtr?.release()

        eventTap = nil
        runLoopSource = nil
        contextPtr = nil
    }
}

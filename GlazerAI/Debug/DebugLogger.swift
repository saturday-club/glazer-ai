// DebugLogger.swift
// GlazerAI
//
// Lightweight in-process debug logger. Active only when the app is
// launched with the --debug flag. All other code calls debugLog(...)
// which always prints to the system console and, when debug mode is
// enabled, appends to the in-memory entry list driving the console UI.

import Combine
import Foundation

// MARK: - Logger

/// Collects timestamped log entries for the debug console.
///
/// Thread safety: `isEnabled` is written once from the main thread before any
/// background work starts. `entries` is always mutated on the main thread via
/// `DispatchQueue.main.async`.
final class DebugLogger: ObservableObject, @unchecked Sendable {

    // MARK: - Shared

    static let shared = DebugLogger()
    private init() {}

    // MARK: - Entry

    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let tag: String
        let message: String
    }

    // MARK: - State

    /// Set once at launch before the coordinator is created. Safe to read from any thread.
    var isEnabled = false

    /// All accumulated entries, newest last. Always mutated on the main thread.
    @Published private(set) var entries: [Entry] = []

    // MARK: - API

    /// Appends to `entries` on the main thread.
    func clear() {
        DispatchQueue.main.async { [weak self] in self?.entries.removeAll() }
    }

    /// Logs `message` to the system console and, when enabled, to the in-memory list.
    /// Safe to call from any thread or actor.
    func log(_ message: String, tag: String = "GlazerAI") {
        print("[\(tag)] \(message)")
        guard isEnabled else { return }
        let entry = Entry(timestamp: .now, tag: tag, message: message)
        DispatchQueue.main.async { [weak self] in
            self?.entries.append(entry)
        }
    }
}

// MARK: - Convenience global

/// Shorthand callable from anywhere without referencing the singleton.
func debugLog(_ message: String, tag: String = "GlazerAI") {
    DebugLogger.shared.log(message, tag: tag)
}

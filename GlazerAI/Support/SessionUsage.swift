// SessionUsage.swift
// GlazerAI
//
// Tracks Claude API token usage for the current app session.
// Reset on every app launch (not persisted).

import Foundation
import Observation

@Observable
final class SessionUsage: @unchecked Sendable {

    nonisolated(unsafe) static let shared = SessionUsage()

    private init() {}

    @MainActor private(set) var inputTokens: Int = 0
    @MainActor private(set) var outputTokens: Int = 0
    @MainActor private(set) var glazeCount: Int = 0

    @MainActor var totalTokens: Int { inputTokens + outputTokens }

    nonisolated func record(inputTokens: Int, outputTokens: Int) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.inputTokens  += inputTokens
            self.outputTokens += outputTokens
            self.glazeCount   += 1
        }
    }
}

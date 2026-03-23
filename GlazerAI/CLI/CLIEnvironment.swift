// CLIEnvironment.swift
// GlazerAI
//
// Resolves and stores the path to the `claude` CLI binary and verifies
// authentication status. Checked once at launch; cached for the process lifetime.

import AppKit
import Foundation

// MARK: - Auth Status

/// Parsed response from `claude auth status --json`.
private struct ClaudeAuthStatus: Decodable {
    let loggedIn: Bool
    let email: String?
    let subscriptionType: String?
}

// MARK: - Environment

/// Resolves the `claude` CLI path at launch and provides it to `ClaudeRunner`.
@MainActor
final class CLIEnvironment {

    // MARK: - Shared

    /// Singleton instance.
    static let shared = CLIEnvironment()

    // MARK: - Properties

    /// Resolved absolute path to the `claude` binary, or `nil` if not found.
    private(set) var claudePath: String?

    // MARK: - Init

    private init() {}

    // MARK: - Testing Support

    /// Clears the cached path. Used in unit tests to simulate a missing CLI.
    func resetForTesting() {
        claudePath = nil
    }

    // MARK: - Public API

    /// Locates `claude`, then verifies the user is authenticated.
    /// Shows an appropriate alert and returns `false` on any failure.
    @discardableResult
    func resolve() async -> Bool {
        guard let path = await locateClaude() else {
            showNotFoundAlert()
            return false
        }

        claudePath = path
        debugLog("claude CLI found at: \(path)", tag: "CLI")

        guard await checkAuth(claudePath: path) else {
            return false
        }

        return true
    }

    // MARK: - Private — Location

    /// Runs `which claude` to find the binary path, with fallbacks for common install locations.
    private func locateClaude() async -> String? {
        // Try interactive+login shell first — sources both .zprofile and .zshrc,
        // so user PATH additions in either file are visible.
        if let path = await runShell("-i", "-l", "-c", "which claude 2>/dev/null") {
            return path
        }

        // Fallback: check well-known install paths directly without spawning a shell.
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func runShell(_ args: String...) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = args
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: output?.isEmpty == false ? output : nil)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Private — Auth

    /// Runs `claude auth status --json` and returns `true` if the user is logged in.
    /// Shows an alert and returns `false` if not authenticated.
    private func checkAuth(claudePath: String) async -> Bool {
        let json = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "\(claudePath) auth status --json"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: output)
            } catch {
                continuation.resume(returning: nil)
            }
        }

        guard let jsonStr = json,
              let data = jsonStr.data(using: .utf8),
              let status = try? JSONDecoder().decode(ClaudeAuthStatus.self, from: data) else {
            // Could not parse auth status — allow through rather than block.
            debugLog("Could not parse auth status; proceeding.", tag: "CLI")
            return true
        }

        debugLog("Auth status: loggedIn=\(status.loggedIn), email=\(status.email ?? "?")", tag: "CLI")

        if !status.loggedIn {
            showNotLoggedInAlert()
            return false
        }

        return true
    }

    // MARK: - Private — Alerts

    private func showNotFoundAlert() {
        let alert = NSAlert()
        alert.messageText = "Claude CLI Not Found"
        // swiftlint:disable:next line_length
        alert.informativeText = "The Claude CLI is required but was not found on your system. Please install it to use GlazerAI."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Install Claude CLI")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "https://claude.ai/download") {
                NSWorkspace.shared.open(url)
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    private func showNotLoggedInAlert() {
        let alert = NSAlert()
        alert.messageText = "Not Logged In to Claude"
        // swiftlint:disable:next line_length
        alert.informativeText = "Glazer AI requires an active Claude session. Please run `claude` in your terminal and log in, then relaunch GlazerAI."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

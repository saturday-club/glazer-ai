// CLIEnvironment.swift
// GlazerAI
//
// Resolves and stores the path to the `claude` CLI binary.
// Checked once at launch; cached for the lifetime of the process.

import AppKit
import Foundation

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

    // MARK: - Public API

    /// Attempts to locate `claude` on `$PATH` via `/usr/bin/which`.
    /// Shows an alert and returns `false` if the CLI is not found.
    @discardableResult
    func resolve() async -> Bool {
        let path = await locateClaude()
        claudePath = path

        if path == nil {
            showNotFoundAlert()
            return false
        }

        print("[Glazer AI] claude CLI found at: \(path ?? "nil")")
        return true
    }

    // MARK: - Private

    /// Runs `which claude` to find the binary path.
    private func locateClaude() async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            // Use login shell to inherit user's PATH
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "which claude"]
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

    /// Displays an alert explaining that the Claude CLI is required.
    private func showNotFoundAlert() {
        let alert = NSAlert()
        alert.messageText = "Glazer AI"
        // swiftlint:disable:next line_length
        alert.informativeText = "The Claude CLI is required but was not found on your system. Please install it to use Glazer AI."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Install Claude CLI")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "https://claude.ai/download") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

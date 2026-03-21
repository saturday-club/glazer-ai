// ClaudeRunner.swift
// GlazerAI
//
// Actor that invokes the `claude -p` CLI and captures its output.
// Runs the process asynchronously with a configurable timeout.

import Foundation

// MARK: - Errors

/// Errors produced by ``ClaudeRunner``.
enum ClaudeError: LocalizedError {
    /// The `claude` CLI binary was not found on PATH.
    case notFound
    /// The process exceeded the allowed timeout.
    case timeout
    /// The process exited with a non-zero status code.
    case executionFailed(stderr: String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "The Claude CLI was not found. "
                + "Please install it from https://claude.ai/download"
        case .timeout:
            return "The Claude CLI did not respond within 60 seconds."
        case .executionFailed(let stderr):
            let detail = stderr.isEmpty ? "Unknown error" : stderr
            return "Claude CLI failed: \(detail)"
        }
    }
}

// MARK: - Runner

/// Invokes `claude -p "<prompt>"` and returns the stdout response.
actor ClaudeRunner {

    /// Timeout in seconds for the claude process.
    private let timeoutSeconds: TimeInterval

    /// Creates a runner with the given timeout.
    /// - Parameter timeoutSeconds: Maximum time to wait for the process. Defaults to 60.
    init(timeoutSeconds: TimeInterval = 60) {
        self.timeoutSeconds = timeoutSeconds
    }

    /// Runs the claude CLI with the given prompt and returns the response text.
    ///
    /// - Parameter prompt: The assembled research prompt to send.
    /// - Returns: The stdout output from claude.
    /// - Throws: ``ClaudeError`` on failure.
    func run(prompt: String) async throws -> String {
        guard let claudePath = await CLIEnvironment.shared.claudePath else {
            throw ClaudeError.notFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            executeProcess(
                claudePath: claudePath,
                prompt: prompt,
                continuation: continuation
            )
        }
    }

    // MARK: - Private

    private func executeProcess(
        claudePath: String,
        prompt: String,
        continuation: CheckedContinuation<String, Error>
    ) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "\(claudePath) -p \(shellEscape(prompt))"]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let timeoutItem = DispatchWorkItem { [weak process] in
            process?.terminate()
        }
        DispatchQueue.global().asyncAfter(
            deadline: .now() + timeoutSeconds,
            execute: timeoutItem
        )

        do {
            try process.run()
            process.waitUntilExit()
            timeoutItem.cancel()

            let result = readResult(process: process, stdout: stdoutPipe, stderr: stderrPipe)
            continuation.resume(with: result)
        } catch {
            timeoutItem.cancel()
            continuation.resume(throwing: ClaudeError.executionFailed(
                stderr: error.localizedDescription
            ))
        }
    }

    private func readResult(
        process: Process,
        stdout: Pipe,
        stderr: Pipe
    ) -> Result<String, Error> {
        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

        if process.terminationReason == .uncaughtSignal {
            return .failure(ClaudeError.timeout)
        } else if process.terminationStatus != 0 {
            return .failure(ClaudeError.executionFailed(stderr: stderrStr))
        } else {
            return .success(stdoutStr)
        }
    }

    /// Shell-escapes a string for safe inclusion in a command.
    private func shellEscape(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}

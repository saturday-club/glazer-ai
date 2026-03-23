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
            return "The Claude CLI did not respond within 120 seconds."
        case .executionFailed(let stderr):
            let detail = stderr.isEmpty ? "Unknown error" : stderr
            return "Claude CLI failed: \(detail)"
        }
    }
}

// MARK: - Output Envelope

private struct ClaudeUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens  = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

/// The JSON envelope that `claude -p --output-format json` wraps its response in.
private struct ClaudeOutputEnvelope: Decodable {
    let isError: Bool
    let result: String
    let usage: ClaudeUsage?

    enum CodingKeys: String, CodingKey {
        case isError = "is_error"
        case result
        case usage
    }
}

// MARK: - Runner

/// Invokes `claude -p --output-format json "<prompt>"` and returns the inner result text.
actor ClaudeRunner {

    /// Timeout in seconds for the claude process.
    private let timeoutSeconds: TimeInterval

    /// Creates a runner with the given timeout.
    /// - Parameter timeoutSeconds: Maximum time to wait for the process. Defaults to 60.
    init(timeoutSeconds: TimeInterval = 120) {
        self.timeoutSeconds = timeoutSeconds
    }

    /// Runs the claude CLI with the given prompt and returns the result text.
    ///
    /// Uses `--output-format json` so the process output is a structured envelope,
    /// giving reliable `is_error` detection and clean extraction of the response text.
    ///
    /// - Parameter prompt: The assembled research prompt to send.
    /// - Returns: The `result` field from the JSON envelope.
    /// - Throws: ``ClaudeError`` on failure.
    func run(prompt: String) async throws -> String {
        guard let claudePath = await CLIEnvironment.shared.claudePath else {
            throw ClaudeError.notFound
        }

        let raw = try await withCheckedThrowingContinuation { continuation in
            executeProcess(
                claudePath: claudePath,
                prompt: prompt,
                continuation: continuation
            )
        }

        return try extractResult(from: raw)
    }

    // MARK: - Private

    private func executeProcess(
        claudePath: String,
        prompt: String,
        continuation: CheckedContinuation<String, Error>
    ) {
        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c",
            "\(claudePath) -p --output-format json --allowedTools web_search"
        ]
        process.standardInput = stdinPipe
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

            // Write prompt to stdin then close so the process sees EOF.
            if let data = prompt.data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(data)
            }
            stdinPipe.fileHandleForWriting.closeFile()

            process.waitUntilExit()
            timeoutItem.cancel()

            let result = readRawOutput(process: process, stdout: stdoutPipe, stderr: stderrPipe)
            continuation.resume(with: result)
        } catch {
            timeoutItem.cancel()
            continuation.resume(throwing: ClaudeError.executionFailed(
                stderr: error.localizedDescription
            ))
        }
    }

    private func readRawOutput(
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

    /// Decodes the JSON envelope and returns `result`, or throws if `is_error` is true.
    private func extractResult(from envelopeJSON: String) throws -> String {
        let data = Data(envelopeJSON.utf8)
        let envelope = (try? JSONDecoder().decode(ClaudeOutputEnvelope.self, from: data))
        guard let env = envelope else {
            // Fallback: envelope not parseable, return raw text as-is
            return envelopeJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if env.isError {
            throw ClaudeError.executionFailed(stderr: env.result)
        }
        if let usage = env.usage {
            SessionUsage.shared.record(
                inputTokens: usage.inputTokens,
                outputTokens: usage.outputTokens
            )
        }
        return env.result
    }

}

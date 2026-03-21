// AIBackendService.swift
// GlazerAI
//
// Protocol contract and error types for the AI backend integration layer.
// Swap in a real implementation without touching any call sites.

import Foundation

// MARK: - Error

/// Errors that can be thrown by any ``AIBackendService`` implementation.
enum AIBackendError: LocalizedError {
    /// The image payload was empty — nothing to send.
    case emptyPayload
    /// A network-level failure occurred.
    case networkFailure(underlying: Error)
    /// The server returned an unexpected HTTP status code.
    case unexpectedResponse(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .emptyPayload:
            return "The captured image was empty and could not be sent."
        case .networkFailure(let error):
            return "Network error: \(error.localizedDescription)"
        case .unexpectedResponse(let code):
            return "Unexpected server response (HTTP \(code))."
        }
    }
}

// MARK: - Protocol

/// Defines the contract for sending a captured image to an AI backend.
///
/// Conform to this protocol to provide a real backend implementation.
/// Inject the concrete type into ``AppCoordinator`` via its initialiser.
protocol AIBackendService: AnyObject, Sendable {
    /// Sends a PNG-encoded image to the AI backend.
    ///
    /// - Parameter image: Raw PNG `Data` of the captured screen region.
    /// - Throws: ``AIBackendError`` on failure.
    func send(image: Data) async throws
}

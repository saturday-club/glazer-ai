// ClaudeResponse.swift
// GlazerAI
//
// Codable types representing the structured JSON response returned by Claude.
// All LLM communication uses this schema as the single source of truth.

import Foundation

// MARK: - Status

/// Top-level status of the Claude response.
enum ClaudeResponseStatus: String, Codable, Sendable {
    /// Profile information was found and processed.
    case success
    /// The OCR text did not contain recognisable LinkedIn profile information.
    case noProfileFound = "no_profile_found"
}

// MARK: - Profile Data

/// Structured LinkedIn profile fields extracted from the screenshot.
struct ProfileData: Codable, Sendable {
    let name: String?
    let headline: String?
    let company: String?
    let location: String?
    let connections: String?
    let about: String?
    let experience: [String]?
    let education: [String]?
    let skills: [String]?
}

// MARK: - Research Data

/// Web-researched findings about the target person, beyond what is in the screenshot.
struct ResearchData: Codable, Sendable {
    /// Notable recent activity: posts, talks, launches, open-source contributions, etc.
    let recentActivity: [String]?
    /// Published articles, papers, or interviews found online.
    let publications: [String]?
    /// Context about their current company: stage, domain, recent news.
    let companyContext: String?
    /// Specific, genuine angles for starting a conversation.
    let conversationAngles: [String]?
}

// MARK: - Top-Level Response

/// The full response envelope returned by Claude.
struct ClaudeResponse: Codable, Sendable {
    /// Whether a LinkedIn profile was found.
    let status: ClaudeResponseStatus
    /// Extracted profile fields. Present only when `status == .success`.
    let profile: ProfileData?
    /// Web-researched findings about the person.
    let research: ResearchData?
    /// Personalised LinkedIn connection note (≤ 300 characters).
    let iceBreakerNote: String?
    /// A short narrative summary of the profile.
    let summary: String?
    /// Human-readable explanation when `status == .noProfileFound`.
    let message: String?
}

// MARK: - Parsing

extension ClaudeResponse {

    /// Errors thrown during JSON parsing.
    enum ParseError: LocalizedError {
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .invalidJSON(let detail):
                return "Could not parse Claude response: \(detail)"
            }
        }
    }

    /// Parses a raw Claude output string into a ``ClaudeResponse``.
    ///
    /// Handles responses wrapped in markdown code fences (` ```json … ``` `)
    /// that some Claude versions emit even when instructed not to.
    static func parse(from raw: String) throws -> ClaudeResponse {
        let json = stripMarkdownFences(from: raw)
        print("[GlazerAI] Raw Claude output (\(raw.count) chars): \(raw.prefix(300))")
        print("[GlazerAI] Extracted JSON (\(json.count) chars): \(json.prefix(300))")

        guard !json.isEmpty else {
            throw ParseError.invalidJSON("Claude returned empty response")
        }
        guard let data = json.data(using: .utf8) else {
            throw ParseError.invalidJSON("Could not encode string as UTF-8")
        }
        do {
            return try JSONDecoder().decode(ClaudeResponse.self, from: data)
        } catch {
            print("[GlazerAI] JSON decode error: \(error)")
            throw ParseError.invalidJSON(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    /// Extracts the JSON object from Claude's response, handling markdown fences,
    /// prose before/after the JSON, and other formatting Claude may add.
    private static func stripMarkdownFences(from raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences if present.
        if text.hasPrefix("```") {
            let lines = text.components(separatedBy: "\n")
            text = lines.dropFirst().dropLast()
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // If the result already starts with '{', use it directly.
        if text.hasPrefix("{") {
            return text
        }

        // Otherwise, find the first '{' and last '}' and extract the JSON object.
        guard let openBrace = text.firstIndex(of: "{"),
              let closeBrace = text.lastIndex(of: "}") else {
            return text
        }
        return String(text[openBrace...closeBrace])
    }
}

// CandidateProfile.swift
// GlazerAI
//
// The sender's professional identity extracted from their uploaded resume.
// Used to personalise ice-breaker connection notes.

import Foundation

/// The GlazerAI user's professional identity.
struct CandidateProfile: Codable, Sendable {
    /// Full name (extracted or entered manually as fallback).
    var name: String
    /// Raw text extracted from the uploaded resume PDF.
    var resumeText: String

    static let empty = CandidateProfile(name: "", resumeText: "")

    /// `true` when a resume has been uploaded.
    var isConfigured: Bool { !resumeText.trimmingCharacters(in: .whitespaces).isEmpty }
}

// MARK: - UserDefaults Persistence

extension CandidateProfile {

    private static let defaultsKey = "candidateProfile"

    static func load() -> CandidateProfile {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let profile = try? JSONDecoder().decode(CandidateProfile.self, from: data) else {
            return .empty
        }
        return profile
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: CandidateProfile.defaultsKey)
    }
}

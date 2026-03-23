// GlazeRecord.swift
// GlazerAI
//
// Persisted record of a single profile glaze.

import Foundation
import GRDB

/// One persisted "glaze" — a profile reachout attempt with its generated ice-breaker.
struct GlazeRecord: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var createdAt: Date
    var name: String?
    var headline: String?
    var company: String?
    var location: String?
    var iceBreakerNote: String?
    var summary: String?
    var ocrText: String
    var researchJSON: String?   // ResearchData encoded as JSON blob
    var imageData: Data?
    var jobDescription: String?  // optional job description used for tailoring
    var tailoredNote: String?    // ice-breaker regenerated with job description

    static let databaseTableName = "glazes"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Equatable & Hashable

extension GlazeRecord: Equatable {
    static func == (lhs: GlazeRecord, rhs: GlazeRecord) -> Bool {
        lhs.id == rhs.id
    }
}

extension GlazeRecord: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Factory

extension GlazeRecord {

    /// Builds a `GlazeRecord` from the pipeline outputs.
    static func make(
        response: ClaudeResponse,
        ocrText: String,
        imageData: Data?
    ) -> GlazeRecord {
        let researchJSON: String? = {
            guard let research = response.research,
                  let data = try? JSONEncoder().encode(research) else { return nil }
            return String(data: data, encoding: .utf8)
        }()

        return GlazeRecord(
            id: nil,
            createdAt: .now,
            name: response.profile?.name,
            headline: response.profile?.headline,
            company: response.profile?.company,
            location: response.profile?.location,
            iceBreakerNote: response.iceBreakerNote,
            summary: response.summary,
            ocrText: ocrText,
            researchJSON: researchJSON,
            imageData: imageData,
            jobDescription: nil,
            tailoredNote: nil
        )
    }
}

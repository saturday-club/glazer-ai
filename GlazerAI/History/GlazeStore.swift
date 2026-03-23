// GlazeStore.swift
// GlazerAI
//
// Repository wrapping the SQLite database via GRDB.
// The database lives in ~/Library/Application Support/GlazerAI/glazes.db.

import Foundation
import GRDB

/// Persists and retrieves ``GlazeRecord`` values from a local SQLite database.
final class GlazeStore: Sendable {

    // MARK: - Shared

    static let shared: GlazeStore = {
        do {
            return try GlazeStore()
        } catch {
            fatalError("[GlazeStore] Failed to open database: \(error)")
        }
    }()

    // MARK: - Private

    private let dbQueue: DatabaseQueue

    // MARK: - Init

    init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("GlazerAI", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let dbURL = dir.appendingPathComponent("glazes.db")
        dbQueue = try DatabaseQueue(path: dbURL.path)
        debugLog("Database at: \(dbURL.path)", tag: "DB")
        try migrate()
    }

    // MARK: - Migrations

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_glazes") { db in
            try db.create(table: "glazes") { tbl in
                tbl.autoIncrementedPrimaryKey("id")
                tbl.column("createdAt", .datetime).notNull()
                tbl.column("name", .text)
                tbl.column("headline", .text)
                tbl.column("company", .text)
                tbl.column("location", .text)
                tbl.column("iceBreakerNote", .text)
                tbl.column("summary", .text)
                tbl.column("ocrText", .text).notNull().defaults(to: "")
                tbl.column("researchJSON", .text)
                tbl.column("imageData", .blob)
            }
        }

        migrator.registerMigration("v2_add_job_description") { db in
            try db.alter(table: "glazes") { tbl in
                tbl.add(column: "jobDescription", .text)
                tbl.add(column: "tailoredNote", .text)
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Write

    /// Inserts a new glaze record, updating its `id` in-place.
    func insert(_ record: inout GlazeRecord) throws {
        try dbQueue.write { db in try record.insert(db) }
        debugLog("Saved glaze for \(record.name ?? "unknown") (id=\(record.id ?? -1))", tag: "DB")
    }

    /// Updates an existing glaze record.
    func update(_ record: GlazeRecord) throws {
        try dbQueue.write { db in try record.update(db) }
    }

    /// Deletes the record with the given id.
    func delete(id: Int64) throws {
        _ = try dbQueue.write { db in try GlazeRecord.deleteOne(db, key: id) }
        debugLog("Deleted glaze id=\(id)", tag: "DB")
    }

    // MARK: - Read

    /// Returns all records, newest first.
    func fetchAll() throws -> [GlazeRecord] {
        try dbQueue.read { db in
            try GlazeRecord.order(Column("createdAt").desc).fetchAll(db)
        }
    }
}

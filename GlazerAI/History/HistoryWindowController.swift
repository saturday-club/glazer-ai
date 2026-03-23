// HistoryWindowController.swift
// GlazerAI
//
// Shows past profile glazes from the SQLite database.

import AppKit
import SwiftUI

// MARK: - Window Controller

@MainActor
final class HistoryWindowController: NSWindowController {

    init() {
        let view = HistoryView()
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "GlazerAI \u{2014} History"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 860, height: 560))
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - History View

private struct HistoryView: View {

    @State private var records: [GlazeRecord] = []
    @State private var selected: GlazeRecord?
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var displayed: [GlazeRecord] {
        guard !searchText.isEmpty else { return records }
        return records.filter { record in
            let nameMatch = record.name?.localizedCaseInsensitiveContains(searchText) ?? false
            let companyMatch = record.company?.localizedCaseInsensitiveContains(searchText) ?? false
            let headlineMatch = record.headline?.localizedCaseInsensitiveContains(searchText) ?? false
            return nameMatch || companyMatch || headlineMatch
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPanel
        }
        .onAppear { reload() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            reload()
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(displayed, id: \.id, selection: $selected) { record in
            sidebarRow(record)
                .tag(record)
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Search by name or company")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .overlay {
            if records.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("Glazed profiles will appear here.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: reload) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
    }

    private func sidebarRow(_ record: GlazeRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.name ?? "Unknown")
                .font(.headline)
                .lineLimit(1)
            if let company = record.company {
                Text(company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    // MARK: Detail

    @ViewBuilder
    private var detailPanel: some View {
        if let record = selected {
            GlazeDetailView(record: record, onDelete: {
                guard let id = record.id else { return }
                try? GlazeStore.shared.delete(id: id)
                selected = nil
                reload()
            })
        } else {
            ContentUnavailableView(
                "Select a Glaze",
                systemImage: "person.crop.rectangle",
                description: Text("Choose a profile from the sidebar.")
            )
        }
    }

    // MARK: Helpers

    private func reload() {
        do {
            records = try GlazeStore.shared.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Detail View

private struct GlazeDetailView: View {

    let record: GlazeRecord
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let note = record.iceBreakerNote { iceBreakerCard(note) }
                if let tailored = record.tailoredNote {
                    tailoredNoteCard(tailored, jobDescription: record.jobDescription)
                }
                profileSection
                if let json = record.researchJSON,
                   let data = json.data(using: .utf8),
                   let research = try? JSONDecoder().decode(ResearchData.self, from: data) {
                    researchSection(research)
                }
                Divider()
                deleteButton
            }
            .padding(20)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.name ?? "Unknown")
                    .font(.title2).bold()
                if let headline = record.headline {
                    Text(headline).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    if let company = record.company {
                        Label(company, systemImage: "building.2").font(.caption)
                    }
                    if let location = record.location {
                        Label(location, systemImage: "mappin").font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(record.createdAt.formatted(date: .long, time: .shortened))
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Ice-breaker

    private func iceBreakerCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Connection Note", systemImage: "envelope.open")
                .font(.headline)
            Text(note)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("\(note.count)/300 chars")
                    .font(.caption)
                    .foregroundStyle(note.count > 300 ? .red : .secondary)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(note, forType: .string)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: Tailored Note

    private func tailoredNoteCard(_ note: String, jobDescription: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tailored Note", systemImage: "briefcase")
                .font(.headline)
            if let jd = jobDescription, !jd.isEmpty {
                Text("Job description: \(jd.prefix(120))…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(note)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("\(note.count)/300 chars")
                    .font(.caption)
                    .foregroundStyle(note.count > 300 ? .red : .secondary)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(note, forType: .string)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.green.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: Profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile").font(.headline)
            if let summary = record.summary {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Research

    private func researchSection(_ research: ResearchData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Research").font(.headline)
            if let ctx = research.companyContext {
                bulletBlock(title: "Company", items: [ctx])
            }
            if let items = research.recentActivity, !items.isEmpty {
                bulletBlock(title: "Recent Activity", items: items)
            }
            if let angles = research.conversationAngles, !angles.isEmpty {
                bulletBlock(title: "Conversation Angles", items: angles)
            }
        }
    }

    private func bulletBlock(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: "circle.fill")
                    .labelStyle(BulletLabelStyle())
                    .font(.callout)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: Delete

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete This Record", systemImage: "trash")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.red)
    }
}

// MARK: - BulletLabelStyle

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 6) {
            configuration.icon
                .font(.system(size: 5))
                .padding(.top, 5)
                .foregroundStyle(.secondary)
            configuration.title
        }
    }
}

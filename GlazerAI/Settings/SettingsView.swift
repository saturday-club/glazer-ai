// SettingsView.swift
// GlazerAI
//
// Candidate profile settings — upload a resume PDF so GlazerAI can
// personalise ice-breaker messages on the user's behalf.

import PDFKit
import SwiftUI

struct SettingsView: View {

    // MARK: - State

    @State private var name: String
    @State private var resumeText: String
    @State private var resumeFileName: String
    @State private var isTargeted = false   // drag-over highlight
    @State private var errorMessage: String?

    var onSave: (CandidateProfile) -> Void
    var onCancel: () -> Void

    // MARK: - Init

    init(profile: CandidateProfile, onSave: @escaping (CandidateProfile) -> Void, onCancel: @escaping () -> Void) {
        _name         = State(initialValue: profile.name)
        _resumeText   = State(initialValue: profile.resumeText)
        _resumeFileName = State(initialValue: profile.resumeText.isEmpty ? "" : "Resume uploaded")
        self.onSave   = onSave
        self.onCancel = onCancel
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                profileTab
                    .tabItem { Label("Profile", systemImage: "person.crop.rectangle") }
                usageTab
                    .tabItem { Label("Usage", systemImage: "chart.bar") }
            }
            .frame(width: 420, height: 360)
            Divider()
            footer
        }
        .frame(width: 420)
    }

    private var profileTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameField
                    resumeSection
                    if let err = errorMessage {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var usageTab: some View {
        UsageView()
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Profile")
                .font(.headline)
            Text("GlazerAI uses your resume to personalise ice-breaker messages.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var nameField: some View {
        LabeledContent("Your Name") {
            TextField("Alex Johnson", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var resumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resume (PDF)")
                .font(.subheadline)
                .fontWeight(.medium)

            dropZone
                .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
                    handleDrop(providers)
                }

            if !resumeFileName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.secondary)
                    Text(resumeFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Remove") {
                        resumeText = ""
                        resumeFileName = ""
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isTargeted ? Color.accentColor.opacity(0.06) : Color.clear)
                )

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Drop PDF here or")
                    .foregroundStyle(.secondary)
                Button("Browse\u{2026}") { browseForPDF() }
                    .buttonStyle(.borderless)
            }
            .padding(20)
        }
        .frame(height: 110)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button("Save") {
                onSave(CandidateProfile(name: name, resumeText: resumeText))
            }
            .keyboardShortcut(.defaultAction)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || resumeText.isEmpty)
        }
        .padding(16)
    }

    // MARK: - PDF Handling

    private func browseForPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadPDF(from: url)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "pdf" else {
                DispatchQueue.main.async { self.errorMessage = "Please drop a PDF file." }
                return
            }
            DispatchQueue.main.async { self.loadPDF(from: url) }
        }
        return true
    }

    private func loadPDF(from url: URL) {
        errorMessage = nil
        guard let pdf = PDFDocument(url: url) else {
            errorMessage = "Could not open PDF."
            return
        }
        let text = (0..<pdf.pageCount)
            .compactMap { pdf.page(at: $0)?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            errorMessage = "No text found in PDF. Make sure it is not image-only."
            return
        }

        resumeText = text
        resumeFileName = url.lastPathComponent
    }
}

// ResultsView.swift
// GlazerAI
//
// SwiftUI view displaying the pipeline results: snip thumbnail,
// OCR text (collapsible), and structured LinkedIn profile data.

import SwiftUI

/// Displays the results of a Glazer AI capture pipeline run.
struct ResultsView: View {

    @Bindable var viewModel: ResultsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                thumbnailSection
                ocrSection
                responseSection
                actionButtons
            }
            .padding(20)
        }
        .frame(minWidth: 500, idealWidth: 620, minHeight: 400, idealHeight: 640)
    }

    // MARK: - Sections

    @ViewBuilder
    private var thumbnailSection: some View {
        if let image = viewModel.snipImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 2)
        }
    }

    @ViewBuilder
    private var ocrSection: some View {
        if !viewModel.ocrText.isEmpty {
            DisclosureGroup(
                "Extracted Text",
                isExpanded: $viewModel.isOCRExpanded
            ) {
                Text(viewModel.ocrText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .font(.headline)
        }
    }

    @ViewBuilder
    private var responseSection: some View {
        switch viewModel.state {
        case .loading:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Thinking\u{2026}")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)

        case .success(let response):
            profileSection(response)

        case .error(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("Error")
                    .font(.headline)
                    .foregroundStyle(.red)

                Text(message)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Profile Display

    @ViewBuilder
    private var jobDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tailor to Job (optional)", systemImage: "briefcase")
                .font(.headline)
            Text("Paste a job description to regenerate a more targeted connection note.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $viewModel.jobDescription)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Button("Regenerate Note") {
                viewModel.requestRefinement()
            }
            .disabled(viewModel.jobDescription.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func profileSection(_ response: ClaudeResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Ice-breaker card — most actionable, shown first
            if let note = response.iceBreakerNote, !note.isEmpty {
                iceBreakerCard(note: note)
                Divider()
            }

            jobDescriptionSection
            Divider()

            if let profile = response.profile {
                profileHeaderView(profile)
                Divider()
                if let about = profile.about {
                    profileFieldSection(title: "About", content: about)
                }
                if let experience = profile.experience, !experience.isEmpty {
                    profileListSection(title: "Experience", items: experience)
                }
                if let education = profile.education, !education.isEmpty {
                    profileListSection(title: "Education", items: education)
                }
                if let skills = profile.skills, !skills.isEmpty {
                    profileChipsSection(title: "Skills", items: skills)
                }
            }

            if let research = response.research {
                researchSection(research)
            }

            if let summary = response.summary {
                Divider()
                profileFieldSection(title: "Summary", content: summary)
            }
        }
    }

    // MARK: - Ice-Breaker Card

    @ViewBuilder
    private func iceBreakerCard(note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Connection Note", systemImage: "envelope.open")
                    .font(.headline)
                Spacer()
                Text("\(note.count)/300")
                    .font(.caption)
                    .foregroundStyle(note.count > 300 ? .red : .secondary)
            }

            Text(note)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("Copy Note") { viewModel.copyIceBreakerNote() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
    }

    // MARK: - Research Section

    @ViewBuilder
    private func researchSection(_ research: ResearchData) -> some View {
        let hasContent = (research.recentActivity?.isEmpty == false)
                      || (research.publications?.isEmpty == false)
                      || research.companyContext != nil
                      || (research.conversationAngles?.isEmpty == false)
        if hasContent {
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Research")
                    .font(.headline)

                if let companyCtx = research.companyContext {
                    profileFieldSection(title: "Company Context", content: companyCtx)
                }
                if let activity = research.recentActivity, !activity.isEmpty {
                    profileListSection(title: "Recent Activity", items: activity)
                }
                if let pubs = research.publications, !pubs.isEmpty {
                    profileListSection(title: "Publications & Talks", items: pubs)
                }
                if let angles = research.conversationAngles, !angles.isEmpty {
                    profileListSection(title: "Conversation Angles", items: angles)
                }
            }
        }
    }

    @ViewBuilder
    private func profileHeaderView(_ profile: ProfileData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = profile.name {
                Text(name)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            if let headline = profile.headline {
                Text(headline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if let company = profile.company {
                    Label(company, systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let location = profile.location {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let connections = profile.connections {
                    Label(connections, systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func profileFieldSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func profileListSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("\u{2022}")
                        .foregroundStyle(.secondary)
                    Text(item)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.body)
            }
        }
    }

    @ViewBuilder
    private func profileChipsSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { skill in
                    Text(skill)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            if viewModel.claudeResponse?.profile != nil {
                Button("Copy Profile") {
                    viewModel.copyResponse()
                }
            }

            Spacer()

            Button("Close") {
                NSApp.keyWindow?.close()
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - FlowLayout

/// A simple wrapping layout for skill chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + (rowWidth > 0 ? spacing : 0) > maxWidth {
                height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
                rowHeight = max(rowHeight, size.height)
            }
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var xOffset = bounds.minX
        var yOffset = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if xOffset + size.width > bounds.maxX && xOffset > bounds.minX {
                xOffset = bounds.minX
                yOffset += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: xOffset, y: yOffset), proposal: ProposedViewSize(size))
            xOffset += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

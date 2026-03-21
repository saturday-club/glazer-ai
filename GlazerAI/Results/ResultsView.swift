// ResultsView.swift
// GlazerAI
//
// SwiftUI view displaying the pipeline results: snip thumbnail,
// OCR text (collapsible), and the Claude response.

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
        .frame(minWidth: 500, idealWidth: 600, minHeight: 400, idealHeight: 600)
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude's Response")
                    .font(.headline)

                Text(response)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

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

    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            if viewModel.responseText != nil {
                Button("Copy Response") {
                    viewModel.copyResponse()
                }
                .keyboardShortcut("c", modifiers: [.command])
            }

            Spacer()

            Button("Close") {
                NSApp.keyWindow?.close()
            }
        }
        .padding(.top, 8)
    }
}

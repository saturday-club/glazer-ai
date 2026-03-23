// DebugConsoleWindowController.swift
// GlazerAI
//
// Floating debug console that streams every DebugLogger entry in real time.
// Shown automatically when the app is launched with --debug.

import AppKit
import SwiftUI

// MARK: - Window Controller

@MainActor
final class DebugConsoleWindowController: NSWindowController {

    init() {
        let view = DebugConsoleView()
        let hosting = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hosting)
        window.title = "GlazerAI — Debug Console"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 780, height: 480))
        window.minSize = NSSize(width: 500, height: 300)
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

// MARK: - Console View

private struct DebugConsoleView: View {

    @ObservedObject private var logger = DebugLogger.shared
    @State private var filter = ""
    @State private var tagFilter = "All"

    private var allTags: [String] { ["All"] + Array(Set(logger.entries.map(\.tag))).sorted() }

    private var displayed: [DebugLogger.Entry] {
        logger.entries.filter { entry in
            let tagOK  = tagFilter == "All" || entry.tag == tagFilter
            let textOK = filter.isEmpty
                || entry.message.localizedCaseInsensitiveContains(filter)
                || entry.tag.localizedCaseInsensitiveContains(filter)
            return tagOK && textOK
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            logList
            Divider()
            statusBar
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter…", text: $filter)
                .textFieldStyle(.plain)

            Divider().frame(height: 16)

            Picker("Tag", selection: $tagFilter) {
                ForEach(allTags, id: \.self) { Text($0) }
            }
            .labelsHidden()
            .frame(width: 140)

            Spacer()

            Button(action: { logger.clear() }, label: { Label("Clear", systemImage: "trash") })
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: Log list

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(displayed) { entry in
                        row(entry: entry)
                            .id(entry.id)
                    }
                }
            }
            .onChange(of: logger.entries.count) { _, _ in
                if let last = displayed.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func row(entry: DebugLogger.Entry) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(entry.timestamp, style: .time)
                .frame(width: 72, alignment: .leading)
                .foregroundStyle(.secondary)

            Text(entry.tag)
                .frame(width: 100, alignment: .leading)
                .foregroundStyle(tagColor(entry.tag))

            Text(entry.message)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    // MARK: Status bar

    private var statusBar: some View {
        HStack {
            Text("\(displayed.count) of \(logger.entries.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    // MARK: Helpers

    private func tagColor(_ tag: String) -> Color {
        switch tag {
        case "Claude": return .blue
        case "OCR":    return .green
        case "CLI":    return .orange
        case "Error":  return .red
        default:       return .secondary
        }
    }
}

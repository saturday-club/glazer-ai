// UsageView.swift
// GlazerAI
//
// Displays Claude API token usage for the current session.

import SwiftUI

struct UsageView: View {

    @State private var usage = SessionUsage.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Current Session")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: "Glazes", value: "\(usage.glazeCount)", icon: "sparkles")
                statCard(title: "Total Tokens", value: formatted(usage.totalTokens), icon: "chart.bar.fill")
                statCard(title: "Input Tokens", value: formatted(usage.inputTokens), icon: "arrow.up.circle")
                statCard(title: "Output Tokens", value: formatted(usage.outputTokens), icon: "arrow.down.circle")
            }

            Text("Tokens reset when the app is restarted.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(16)
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatted(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

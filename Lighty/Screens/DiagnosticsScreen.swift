import SwiftUI
import UIKit

/// On-device diagnostics: the BLE event log plus a copy action, so a test
/// session can be reported without attaching a debugger.
struct DiagnosticsScreen: View {
    @ObservedObject private var log = DiagnosticsLog.shared
    let strings: Strings

    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: SolariumTheme.cardSpacing) {
                if log.entries.isEmpty {
                    SolariumCard {
                        Text(strings.diagnosticsEmpty)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    SolariumCard {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(log.entries.enumerated()), id: \.element.id) { index, entry in
                                entryRow(entry)
                                if index < log.entries.count - 1 {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle(strings.diagnosticsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = log.report
                        withAnimation(.easeOut(duration: 0.2)) { copied = true }
                    } label: {
                        Label(strings.copyDiagnostics, systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        log.clear()
                    } label: {
                        Label(strings.clearLog, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if copied {
                Text("Copied")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassSurface(cornerRadius: 14)
                    .padding(.bottom, 16)
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        withAnimation(.easeOut(duration: 0.2)) { copied = false }
                    }
            }
        }
    }

    private func entryRow(_ entry: DiagnosticEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.message)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
            HStack(spacing: 6) {
                Text(entry.level.rawValue)
                    .font(.caption2.bold())
                    .foregroundStyle(color(for: entry.level))
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for level: DiagnosticEntry.Level) -> Color {
        switch level {
        case .info: return .secondary
        case .warning: return .orange
        case .error: return .red
        }
    }
}

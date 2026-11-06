import SwiftUI
import UIKit

/// On-device diagnostics: the BLE event log plus a copy action, so a test
/// session can be reported without attaching a debugger.
struct DiagnosticsScreen: View {
    @ObservedObject private var log = DiagnosticsLog.shared
    let strings: Strings

    @State private var copied = false

    var body: some View {
        List {
            if log.entries.isEmpty {
                Text(strings.diagnosticsEmpty)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(log.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.message)
                            .font(.system(.footnote, design: .monospaced))
                        HStack(spacing: 6) {
                            Text(entry.level.rawValue)
                                .font(.caption2.bold())
                                .foregroundStyle(color(for: entry.level))
                            Text(entry.date, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(strings.diagnosticsTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = log.report
                        copied = true
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
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
    }

    private func color(for level: DiagnosticEntry.Level) -> Color {
        switch level {
        case .info: return .secondary
        case .warning: return .orange
        case .error: return .red
        }
    }
}

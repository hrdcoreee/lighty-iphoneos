import Combine
import Foundation

/// In-memory ring buffer of diagnostic lines, surfaced in the UI so an
/// on-device test session can be reported without attaching a debugger.
///
/// Main-actor isolated because every producer (CoreBluetooth delegate
/// callbacks are hopped to the main queue) also touches the UI.
@MainActor
final class DiagnosticsLog: ObservableObject {

    static let shared = DiagnosticsLog()

    /// Newest first, capped so a long session cannot grow without bound.
    @Published private(set) var entries: [DiagnosticEntry] = []

    private let limit: Int

    init(limit: Int = 400) {
        self.limit = limit
    }

    func log(_ message: String, level: DiagnosticEntry.Level = .info) {
        entries.insert(DiagnosticEntry(message, level: level), at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    func clear() {
        entries.removeAll()
    }

    /// Plain-text dump used by the "copy diagnostics" action.
    var report: String {
        let formatter = ISO8601DateFormatter()
        return entries
            .reversed()
            .map { "[\(formatter.string(from: $0.date))] \($0.level.rawValue): \($0.message)" }
            .joined(separator: "\n")
    }
}

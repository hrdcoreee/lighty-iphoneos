import Foundation

/// A device discovered during a BLE scan.
///
/// iOS never exposes a hardware MAC address, so `id` is the CoreBluetooth
/// `CBPeripheral.identifier`: a per-host, per-app UUID that is stable for the
/// lifetime of the installation but not portable between devices. Persisting
/// the Android `address` concept is therefore impossible on iOS.
struct ScannedDevice: Identifiable, Equatable {
    let id: UUID
    let name: String?
    let rssi: Int
    /// True when the advertisement looks like an ELK-BLEDOM controller.
    let isElk: Bool

    /// Signal quality bucket, 0 (weak) .. 4 (excellent), from RSSI in dBm.
    var signalLevel: Int {
        switch rssi {
        case (-55)...: return 4
        case (-67)...: return 3
        case (-80)...: return 2
        case (-90)...: return 1
        default: return 0
        }
    }
}

/// Lifecycle of the CoreBluetooth connection to a single peripheral.
enum ConnectionState: String {
    case disconnected
    case connecting
    case connected
    case failed
}

/// A strip the user has bound; the app auto-connects to it on launch.
struct BoundDevice: Codable, Equatable {
    /// CoreBluetooth peripheral identifier (see `ScannedDevice.id`).
    let id: UUID
    let name: String?

    func toScannedDevice() -> ScannedDevice {
        ScannedDevice(id: id, name: name, rssi: 0, isElk: true)
    }
}

/// A single timestamped line in the on-device diagnostics log.
struct DiagnosticEntry: Identifiable {
    enum Level: String {
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    let id = UUID()
    let date: Date
    let level: Level
    let message: String

    init(_ message: String, level: Level = .info, date: Date = Date()) {
        self.message = message
        self.level = level
        self.date = date
    }
}

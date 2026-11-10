import CoreBluetooth
import Foundation

/// Thin, delegate-driven wrapper around `CBCentralManager` + a single
/// `CBPeripheral` connection.
///
/// Deliberately low level: it owns scanning, the GATT lifecycle and the paced
/// write queue, and reports everything through delegates. Higher-level policy
/// (bound device, auto-reconnect, persistence) lives in `LightyController`.
@MainActor
final class BleCentral: NSObject {

    // MARK: Callbacks

    var onStateChange: ((CBManagerState) -> Void)?
    var onScanResult: ((ScannedDevice) -> Void)?
    var onConnectionState: ((ConnectionState) -> Void)?
    var onPeripheralName: ((UUID, String?) -> Void)?
    var onLog: ((String, DiagnosticEntry.Level) -> Void)?

    // MARK: CoreBluetooth

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?

    /// Retains discovered peripherals so CoreBluetooth does not deallocate them
    /// before connection.
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]

    /// Maps CoreBluetooth identifiers to the discovered device metadata.
    private var knownDevices: [UUID: ScannedDevice] = [:]

    private static let elkServiceUUIDs = [
        CBUUID(string: "FFF0"),
        CBUUID(string: ElkProtocol.serviceUUID),
    ]
    private static let elkWriteCharacteristicUUIDs = [
        CBUUID(string: "FFF3"),
        CBUUID(string: ElkProtocol.writeCharacteristicUUID),
    ]

    private var isScanning = false
    private var shouldBeScanning = false

    // MARK: Write pipeline

    /// Serial queue of frames. `CBCentralManager` only tolerates one outstanding
    /// write without response per connection, so frames are paced.
    private var writeQueue: [Data] = []
    private var writeInFlight = false
    private var writeTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
    }

    // MARK: State

    var bluetoothState: CBManagerState { central.state }

    func peripheral(for id: UUID) -> CBPeripheral? {
        discoveredPeripherals[id] ?? central.retrievePeripherals(withIdentifiers: [id]).first
    }

    // MARK: Scanning

    /// Starts a scan that keeps running until `stopScan()`.
    ///
    /// `allowDuplicates` is required so RSSI keeps updating, which the signal
    /// bars on the scan screen depend on.
    func startScan() {
        shouldBeScanning = true
        guard central.state == .poweredOn else {
            log("Scan requested while Bluetooth is \(BleCentral.describe(central.state))")
            return
        }
        guard !isScanning else { return }

        discoveredPeripherals.removeAll()

        let options: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ]
        // Passing nil services scans for everything; the ELK service UUID is a
        // vendor 16-bit alias which some clones do not advertise reliably.
        central.scanForPeripherals(withServices: nil, options: options)
        isScanning = true
        log("Scan started")
    }

    func stopScan() {
        shouldBeScanning = false
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        log("Scan stopped")
    }

    // MARK: Connection

    func connect(to device: ScannedDevice) {
        stopScan()

        guard let target = peripheral(for: device.id) else {
            log("No peripheral handle for \(device.id)", level: .error)
            onConnectionState?(.failed)
            return
        }

        if let existing = peripheral, existing.identifier != target.identifier {
            disconnect()
        }

        target.delegate = self
        peripheral = target
        knownDevices[device.id] = device

        if target.state == .connected {
            log("Already connected to \(device.name ?? device.id.uuidString)")
            onConnectionState?(.connected)
            drainWriteQueue()
            return
        }

        onConnectionState?(.connecting)
        log("Connecting to \(device.name ?? device.id.uuidString)")
        central.connect(target, options: nil)
    }

    func disconnect() {
        writeTimeoutTask?.cancel()
        writeTimeoutTask = nil
        writeQueue.removeAll()
        writeInFlight = false
        writeCharacteristic = nil

        if let peripheral {
            if peripheral.state != .disconnected {
                central.cancelPeripheralConnection(peripheral)
            }
            peripheral.delegate = nil
        }
        peripheral = nil
        onConnectionState?(.disconnected)
    }

    func readRSSI() {
        peripheral?.readRSSI()
    }

    // MARK: Writing

    /// Enqueues a 9-byte ELK frame. Safe to spam; the queue paces transmission.
    func send(_ frame: [UInt8]) {
        guard ElkProtocol.isValidFrame(frame) else {
            log("Refusing malformed frame \(ElkProtocol.hexString(frame))", level: .error)
            return
        }
        writeQueue.append(Data(frame))
        drainWriteQueue()
    }

    private func drainWriteQueue() {
        guard !writeInFlight,
              let peripheral,
              peripheral.state == .connected,
              let characteristic = writeCharacteristic,
              !writeQueue.isEmpty
        else { return }

        let payload = writeQueue.removeFirst()
        writeInFlight = true

        // ELK controllers expose a write-without-response characteristic and
        // are tolerant of rapid writes, but without a pacing delay iOS drops
        // frames silently. Mirrors the Android `WRITE_TIMEOUT_MS` gate.
        let writeType: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse

        peripheral.writeValue(payload, for: characteristic, type: writeType)

        if writeType == .withoutResponse {
            // No callback will arrive; release the slot after a short pause.
            writeTimeoutTask?.cancel()
            writeTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000)
                guard !Task.isCancelled else { return }
                self?.writeInFlight = false
                self?.drainWriteQueue()
            }
        } else {
            writeTimeoutTask?.cancel()
            writeTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled else { return }
                self?.onLog?("Write ack timeout", .warning)
                self?.writeInFlight = false
                self?.drainWriteQueue()
            }
        }
    }

    private func finishWrite(success: Bool) {
        writeTimeoutTask?.cancel()
        writeTimeoutTask = nil
        if !success {
            log("Characteristic write failed", level: .error)
        }
        writeInFlight = false
        drainWriteQueue()
    }

    // MARK: Helpers

    private func log(_ message: String, level: DiagnosticEntry.Level = .info) {
        onLog?(message, level)
    }

    static func describe(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn: return "poweredOn"
        case .poweredOff: return "poweredOff"
        case .unauthorized: return "unauthorized"
        case .unsupported: return "unsupported"
        case .resetting: return "resetting"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BleCentral: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            self.onLog?("Bluetooth state: \(BleCentral.describe(state))", state == .poweredOn ? .info : .warning)
            self.onStateChange?(state)

            if state == .poweredOn, self.shouldBeScanning, !self.isScanning {
                self.startScan()
            } else if state != .poweredOn {
                if self.isScanning {
                    self.isScanning = false
                }
                if self.peripheral != nil {
                    self.disconnect()
                }
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // Copy everything out of the non-Sendable CoreBluetooth values before
        // hopping to the main actor.
        let id = peripheral.identifier
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let peripheralName = peripheral.name
        let rssi = RSSI.intValue
        let advertisedServices = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
            .map(\.uuidString) ?? []

        Task { @MainActor in
            self.discoveredPeripherals[id] = peripheral
            let name = advertisedName ?? peripheralName
            let device = ScannedDevice(
                id: id,
                name: name,
                rssi: rssi,
                isElk: ElkMatcher.isElkLike(name: name, advertisedServiceUUIDs: advertisedServices)
            )
            self.knownDevices[id] = device
            self.onScanResult?(device)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let id = peripheral.identifier
        Task { @MainActor in
            self.onLog?("Connected to \(id.uuidString); discovering services", .info)
            self.onConnectionState?(.connecting)
            peripheral.discoverServices(BleCentral.elkServiceUUIDs)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let identifier = peripheral.identifier
        let description = error?.localizedDescription ?? "no error"
        Task { @MainActor in
            self.onLog?("Failed to connect to \(identifier.uuidString): \(description)", .error)
            self.writeTimeoutTask?.cancel()
            self.writeTimeoutTask = nil
            self.writeQueue.removeAll()
            self.writeInFlight = false
            self.writeCharacteristic = nil
            self.peripheral = nil
            self.onConnectionState?(.failed)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let identifier = peripheral.identifier
        let description = error?.localizedDescription
        Task { @MainActor in
            if let description {
                self.onLog?("Disconnected from \(identifier.uuidString): \(description)", .warning)
            } else {
                self.onLog?("Disconnected from \(identifier.uuidString)", .info)
            }
            self.writeTimeoutTask?.cancel()
            self.writeTimeoutTask = nil
            self.writeQueue.removeAll()
            self.writeInFlight = false
            self.writeCharacteristic = nil
            self.peripheral = nil
            self.onConnectionState?(error == nil ? .disconnected : .failed)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BleCentral: CBPeripheralDelegate {

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let identifier = peripheral.identifier
        let services = (peripheral.services ?? []).map(\.uuid.uuidString)
        let description = error?.localizedDescription
        Task { @MainActor in
            if let description {
                self.onLog?("Service discovery failed: \(description)", .error)
                self.onConnectionState?(.failed)
                return
            }

            self.log("Services: \(services.joined(separator: ", "))")

            guard let service = peripheral.services?
                .first(where: { BleCentral.elkServiceUUIDs.contains($0.uuid) })
            else {
                self.onLog?("ELK service not found", .error)
                self.onConnectionState?(.failed)
                return
            }

            peripheral.discoverCharacteristics(
                BleCentral.elkWriteCharacteristicUUIDs,
                for: service
            )
            _ = identifier
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        let characteristics = (service.characteristics ?? []).map(\.uuid.uuidString)
        let match = service.characteristics?
            .first(where: { BleCentral.elkWriteCharacteristicUUIDs.contains($0.uuid) })
        let description = error?.localizedDescription

        Task { @MainActor in
            if let description {
                self.onLog?("Characteristic discovery failed: \(description)", .error)
                self.onConnectionState?(.failed)
                return
            }

            self.log("Characteristics: \(characteristics.joined(separator: ", "))")

            guard let match else {
                self.onLog?("Write characteristic not found", .error)
                self.onConnectionState?(.failed)
                return
            }

            self.writeCharacteristic = match
            self.onConnectionState?(.connected)
            self.drainWriteQueue()
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let description = error?.localizedDescription
        Task { @MainActor in
            if let description {
                self.onLog?("Write error: \(description)", .error)
            }
            self.finishWrite(success: description == nil)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let value = characteristic.value
        let uuid = characteristic.uuid.uuidString
        Task { @MainActor in
            if let error {
                self.onLog?("Notify error on \(uuid): \(error.localizedDescription)", .error)
                return
            }
            if let value {
                self.log("Notify \(uuid): \(ElkProtocol.hexString([UInt8](value)))")
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let value = RSSI.intValue
        let identifier = peripheral.identifier
        Task { @MainActor in
            if let error {
                self.onLog?("RSSI read failed: \(error.localizedDescription)", .warning)
                return
            }
            if let device = self.knownDevices[identifier] {
                let updated = ScannedDevice(
                    id: device.id,
                    name: device.name,
                    rssi: value,
                    isElk: device.isElk
                )
                self.knownDevices[identifier] = updated
                self.onScanResult?(updated)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let uuid = characteristic.uuid.uuidString
        let isNotifying = characteristic.isNotifying
        let errorDescription = error?.localizedDescription
        Task { @MainActor in
            if let errorDescription {
                self.onLog?("Notify state error on \(uuid): \(errorDescription)", .error)
            } else {
                self.log("Notify \(isNotifying ? "enabled" : "disabled") on \(uuid)")
            }
        }
    }
}

import Combine
import CoreBluetooth
import Foundation

/// Application-level BLE policy: persistent strip state, the bound device,
/// auto-reconnect and the paced color pipeline.
///
/// This is the SwiftUI-facing counterpart of the Android `LightyBleManager`
/// singleton, but injected as an `ObservableObject` instead of a static singleton
/// so it can be constructed with a test double.
@MainActor
final class LightyController: ObservableObject {

    // MARK: Published state

    @Published private(set) var scanning = false
    @Published private(set) var devices: [ScannedDevice] = []
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var boundDevice: BoundDevice?
    @Published private(set) var bluetoothState: CBManagerState = .unknown

    @Published private(set) var isOn: Bool
    @Published private(set) var hsv: HSVColor
    @Published var showAllDevices: Bool {
        didSet {
            defaults.set(showAllDevices, forKey: Keys.showAllDevices)
            rebuildVisibleDevices()
        }
    }

    // MARK: Collaborators

    private let central: BleCentral
    private let defaults: UserDefaults
    private let log: DiagnosticsLog
    private let boundStore: BoundDeviceStore

    // MARK: Private state

    private var found: [UUID: ScannedDevice] = [:]
    private var boundPingTask: Task<Void, Never>?
    private var idleDisconnectTask: Task<Void, Never>?
    private var colorSendTask: Task<Void, Never>?
    private var isForeground = true

    private enum Keys {
        static let power = "lighty.power"
        static let hue = "lighty.hue"
        static let saturation = "lighty.saturation"
        static let value = "lighty.value"
        static let showAllDevices = "lighty.showAllDevices"
    }

    private enum Timing {
        /// Mirrors the Android `COLOR_SEND_INTERVAL_MS` pacing.
        static let colorSendInterval: UInt64 = 30_000_000
        static let pingInterval: UInt64 = 10_000_000_000
        static let backgroundIdleTimeout: UInt64 = 15_000_000_000
    }

    /// `central` and `log` are injected rather than defaulted in the signature:
    /// a default argument expression is evaluated in a nonisolated context and
    /// cannot touch the main-actor isolated `BleCentral`/`DiagnosticsLog`.
    init(
        defaults: UserDefaults = .standard,
        central: BleCentral? = nil,
        log: DiagnosticsLog? = nil
    ) {
        self.defaults = defaults
        self.central = central ?? BleCentral()
        self.log = log ?? .shared
        self.boundStore = BoundDeviceStore(defaults: defaults)

        self.isOn = defaults.bool(forKey: Keys.power)
        self.hsv = HSVColor(
            hue: defaults.object(forKey: Keys.hue) as? Double ?? 0,
            saturation: defaults.object(forKey: Keys.saturation) as? Double ?? 1,
            brightness: defaults.object(forKey: Keys.value) as? Double ?? 1
        )
        self.showAllDevices = defaults.bool(forKey: Keys.showAllDevices)
        self.boundDevice = boundStore.current

        wireCallbacks()

        if boundDevice != nil {
            self.log.log("Bound device restored; connecting on launch")
            connectBound()
        }
    }

    // MARK: Wiring

    private func wireCallbacks() {
        central.onLog = { [weak self] message, level in
            self?.log.log(message, level: level)
        }

        central.onStateChange = { [weak self] state in
            guard let self else { return }
            self.bluetoothState = state
            if state == .poweredOn, self.boundDevice != nil {
                self.connectBound()
            }
        }

        central.onScanResult = { [weak self] device in
            guard let self else { return }
            self.found[device.id] = device
            self.rebuildVisibleDevices()
        }

        central.onConnectionState = { [weak self] state in
            guard let self else { return }
            let previous = self.connectionState
            self.connectionState = state
            guard previous != state else { return }
            self.log.log("Connection: \(previous.rawValue) -> \(state.rawValue)")

            if state == .connected {
                self.applySavedStateToDevice()
            }
        }
    }

    private func rebuildVisibleDevices() {
        let all = Array(found.values)
        let visible = showAllDevices ? all : all.filter(\.isElk)
        devices = visible.sorted {
            if $0.isElk != $1.isElk { return $0.isElk }
            return $0.rssi > $1.rssi
        }
    }

    // MARK: Lifecycle

    func setForeground(_ foreground: Bool) {
        isForeground = foreground
        if foreground {
            idleDisconnectTask?.cancel()
            idleDisconnectTask = nil
            if let boundDevice {
                startBoundLoop()
                if connectionState == .disconnected || connectionState == .failed {
                    central.connect(to: boundDevice.toScannedDevice())
                }
            }
        } else {
            boundPingTask?.cancel()
            boundPingTask = nil
            scheduleIdleDisconnect()
        }
    }

    private func scheduleIdleDisconnect() {
        guard !isForeground else { return }
        idleDisconnectTask?.cancel()
        idleDisconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Timing.backgroundIdleTimeout)
            guard !Task.isCancelled, let self, !self.isForeground else { return }
            if self.connectionState != .disconnected {
                self.log.log("Idle timeout; disconnecting")
                self.central.disconnect()
            }
        }
    }

    // MARK: Scanning

    var isBluetoothReady: Bool { bluetoothState == .poweredOn }

    func toggleScan() {
        scanning ? stopScan() : startScan()
    }

    func startScan() {
        found.removeAll()
        rebuildVisibleDevices()
        scanning = true
        central.startScan()
    }

    func stopScan() {
        scanning = false
        central.stopScan()
    }

    // MARK: Binding

    func bindAndConnect(_ device: ScannedDevice) {
        let bound = BoundDevice(id: device.id, name: device.name)
        boundDevice = bound
        // Written once here and never rewritten: the pairing survives relaunch.
        boundStore.save(bound)
        log.log("Bound device \(device.name ?? device.id.uuidString)")

        // A peripheral handle for an identifier only exists after discovery, so
        // the freshly scanned object is the one to connect to.
        central.connect(to: device)
        if isForeground { startBoundLoop() }
    }

    func unbind() {
        boundPingTask?.cancel()
        boundPingTask = nil
        boundDevice = nil
        boundStore.clear()
        central.disconnect()
        startScan()
    }

    private func connectBound() {
        guard let boundDevice else { return }
        central.connect(to: boundDevice.toScannedDevice())
    }

    private func startBoundLoop() {
        boundPingTask?.cancel()
        boundPingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let bound = self.boundDevice else { return }
                switch self.connectionState {
                case .disconnected, .failed:
                    self.central.connect(to: bound.toScannedDevice())
                case .connected:
                    self.central.readRSSI()
                case .connecting:
                    break
                }
                try? await Task.sleep(nanoseconds: Timing.pingInterval)
            }
        }
    }

    // MARK: Light control

    func togglePower() { setPower(!isOn) }

    func setPower(_ on: Bool) {
        isOn = on
        persistLight()
        if on {
            ensureConnectedAndSend(ElkProtocol.powerOn)
            sendColorNow()
        } else {
            ensureConnectedAndSend(ElkProtocol.powerOff)
        }
    }

    func setHue(_ hue: Double) {
        guard isOn else { return }
        update(hue: hue)
    }

    func setSaturationValue(saturation: Double, brightness: Double) {
        guard isOn else { return }
        update(saturation: saturation, brightness: brightness)
    }

    func setBrightness(_ brightness: Double) {
        guard isOn else { return }
        update(brightness: brightness)
    }

    func stepBrightness(_ delta: Double) {
        guard isOn else { return }
        setBrightness(min(max(hsv.brightness + delta, 0.05), 1))
    }

    /// Applies a preset swatch, turning the strip on first if needed.
    func applyPreset(_ preset: HSVColor) {
        if !isOn {
            isOn = true
            persistLight()
            ensureConnectedAndSend(ElkProtocol.powerOn)
        }
        update(hue: preset.hue, saturation: preset.saturation, brightness: preset.brightness)
    }

    private func update(hue: Double? = nil, saturation: Double? = nil, brightness: Double? = nil) {
        var next = hsv
        if let hue { next.hue = ((hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) }
        if let saturation { next.saturation = min(max(saturation, 0), 1) }
        if let brightness { next.brightness = min(max(brightness, 0), 1) }
        hsv = next
        persistLight()
        enqueueColor(throttled: true)
        scheduleIdleDisconnect()
    }

    private func sendColorNow() {
        enqueueColor(throttled: false)
    }

    private func enqueueColor(throttled: Bool) {
        let frame = hsv.elkFrame
        if throttled {
            // Coalesce rapid slider updates down to the Android pacing interval.
            colorSendTask?.cancel()
            colorSendTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: Timing.colorSendInterval)
                guard !Task.isCancelled, let self else { return }
                self.ensureConnectedAndSend(frame)
            }
        } else {
            ensureConnectedAndSend(frame)
        }
    }

    private func ensureConnectedAndSend(_ frame: [UInt8]) {
        guard let boundDevice else { return }
        switch connectionState {
        case .connected:
            central.send(frame)
        case .disconnected, .failed:
            central.connect(to: boundDevice.toScannedDevice())
            pendingFrames.append(frame)
        case .connecting:
            pendingFrames.append(frame)
        }
        scheduleIdleDisconnect()
    }

    private var pendingFrames: [[UInt8]] = []

    private func applySavedStateToDevice() {
        if !pendingFrames.isEmpty {
            let frames = pendingFrames
            pendingFrames.removeAll()
            log.log("Flushing \(frames.count) queued frame(s)")
            frames.forEach { central.send($0) }
            return
        }
        if isOn {
            central.send(ElkProtocol.powerOn)
            sendColorNow()
        } else {
            central.send(ElkProtocol.powerOff)
        }
    }

    // MARK: Persistence

    private func persistLight() {
        defaults.set(isOn, forKey: Keys.power)
        defaults.set(hsv.hue, forKey: Keys.hue)
        defaults.set(hsv.saturation, forKey: Keys.saturation)
        defaults.set(hsv.brightness, forKey: Keys.value)
    }

}

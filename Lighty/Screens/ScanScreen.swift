import CoreBluetooth
import SwiftUI

/// Pairing screen: the first thing the app shows, and the only screen until a
/// strip is bound. Discovery starts automatically, mirroring the Android
/// `LaunchedEffect(boundDevice == null) { startScan() }`.
struct ScanScreen: View {
    @EnvironmentObject private var controller: LightyController

    let strings: Strings
    let onOpenSettings: () -> Void

    var body: some View {
        List {
            Section {
                header
            }

            if controller.bluetoothState != .poweredOn {
                Section {
                    BluetoothOffBanner(strings: strings)
                }
            } else if controller.devices.isEmpty {
                Section {
                    EmptyState(strings: strings, isScanning: controller.scanning)
                }
            } else {
                Section(strings.devicesFound(controller.devices.count)) {
                    ForEach(controller.devices) { device in
                        Button {
                            controller.bindAndConnect(device)
                        } label: {
                            DeviceRow(device: device, strings: strings)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(strings.scanTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onOpenSettings) {
                    Label(strings.settingsTitle, systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(controller.scanning ? strings.stopScan : strings.scan) {
                    controller.toggleScan()
                }
                .disabled(controller.bluetoothState != .poweredOn)
            }
        }
        .onAppear { startScanIfReady() }
        .onChange(of: controller.bluetoothState) { _ in startScanIfReady() }
    }

    /// Scanning is idempotent in `LightyController`, so a redundant call is safe.
    private func startScanIfReady() {
        guard !controller.scanning, controller.isBluetoothReady else { return }
        controller.startScan()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.scanSubtitle)
                .font(.headline)
            HStack(spacing: 8) {
                if controller.scanning {
                    ProgressView().controlSize(.small)
                }
                Text(controller.scanning ? strings.searching : strings.readyToScan)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DeviceRow: View {
    let device: ScannedDevice
    let strings: Strings

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(device.isElk ? Color.accentColor : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name ?? strings.unknownDevice)
                    .font(.body)
                Text(device.id.uuidString.prefix(8) + "...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if device.isElk {
                Text("ELK")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }

            SignalBars(level: device.signalLevel)
        }
        .contentShape(Rectangle())
    }
}

private struct BluetoothOffBanner: View {
    let strings: Strings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(strings.bluetoothOffTitle, systemImage: "bluetooth.slash")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(strings.bluetoothOffBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyState: View {
    let strings: Strings
    let isScanning: Bool

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(isScanning ? strings.searching : strings.readyToScan)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.vertical, 24)
    }
}

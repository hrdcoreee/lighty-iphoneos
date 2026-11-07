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
        SolariumScaffold {
            SolariumHeader(
                title: strings.scanTitle,
                subtitle: strings.scanSubtitle
            ) {
                HStack(spacing: 8) {
                    if controller.scanning {
                        ProgressView().controlSize(.small)
                    }
                    scanButton
                }
            }

            if controller.bluetoothState != .poweredOn {
                BluetoothOffCard(strings: strings)
            } else if controller.devices.isEmpty {
                EmptyStateCard(strings: strings, isScanning: controller.scanning)
            } else {
                devicesCard
            }

            scanFilterCard
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onOpenSettings) {
                    Label(strings.settingsTitle, systemImage: "gearshape")
                }
            }
        }
        .onAppear { startScanIfReady() }
        .onChange(of: controller.bluetoothState) { _ in startScanIfReady() }
    }

    private var scanButton: some View {
        Button {
            controller.toggleScan()
        } label: {
            Text(controller.scanning ? strings.stopScan : strings.scan)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassSurface(cornerRadius: 16)
        .disabled(controller.bluetoothState != .poweredOn)
    }

    private var devicesCard: some View {
        SolariumCard(strings.devicesFound(controller.devices.count)) {
            VStack(spacing: 0) {
                ForEach(Array(controller.devices.enumerated()), id: \.element.id) { index, device in
                    Button {
                        controller.bindAndConnect(device)
                    } label: {
                        DeviceRow(device: device, strings: strings)
                    }
                    .buttonStyle(.plain)

                    if index < controller.devices.count - 1 {
                        Divider().opacity(0.35).padding(.leading, 40)
                    }
                }
            }
        }
    }

    private var scanFilterCard: some View {
        SolariumCard {
            Toggle(isOn: Binding(
                get: { controller.showAllDevices },
                set: { controller.showAllDevices = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(strings.showAllDevices)
                        .font(.subheadline)
                    Text(strings.showAllDevicesDesc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Scanning is idempotent in `LightyController`, so a redundant call is safe.
    private func startScanIfReady() {
        guard !controller.scanning, controller.isBluetoothReady else { return }
        controller.startScan()
    }
}

private struct DeviceRow: View {
    let device: ScannedDevice
    let strings: Strings

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(device.isElk ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name ?? strings.unknownDevice)
                    .font(.body)
                    .lineLimit(1)
                Text(device.id.uuidString.prefix(8) + "...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if device.isElk {
                Text("ELK")
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.18), in: Capsule())
            }

            SignalBars(level: device.signalLevel)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

private struct BluetoothOffCard: View {
    let strings: Strings

    var body: some View {
        SolariumCard(tint: .orange) {
            VStack(alignment: .leading, spacing: 6) {
                Label(strings.bluetoothOffTitle, systemImage: "bluetooth.slash")
                    .font(.headline)
                Text(strings.bluetoothOffBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyStateCard: View {
    let strings: Strings
    let isScanning: Bool

    var body: some View {
        SolariumCard {
            VStack(spacing: 10) {
                // `symbolEffect` requires iOS 17; the deployment target is 16,
                // so the spinner-free pulse is simply omitted there.
                Group {
                    if #available(iOS 17.0, *) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(.secondary)
                            .symbolEffect(.pulse, isActive: isScanning)
                    } else {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(isScanning ? strings.searching : strings.readyToScan)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }
}

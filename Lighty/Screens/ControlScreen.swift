import SwiftUI

/// Main strip control: on/off, brightness, presets and the HSV picker.
struct ControlScreen: View {
    @EnvironmentObject private var controller: LightyController
    let strings: Strings
    let onOpenSettings: () -> Void

    private var isOnline: Bool { controller.connectionState == .connected }

    var body: some View {
        List {
            Section {
                statusRow
            }

            Section {
                Toggle(isOn: Binding(
                    get: { controller.isOn },
                    set: { controller.setPower($0) }
                )) {
                    Label(strings.powerLabel, systemImage: "power")
                }
                .disabled(controller.boundDevice == nil)
            }

            Section(strings.brightnessLabel) {
                HStack(spacing: 12) {
                    Image(systemName: "sun.min")
                    Slider(
                        value: Binding(
                            get: { controller.hsv.brightness },
                            set: { controller.setBrightness($0) }
                        ),
                        in: 0.05...1
                    )
                    .disabled(!controller.isOn)
                    Image(systemName: "sun.max")
                }
            }

            Section(strings.quickColors) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
                    spacing: 12
                ) {
                    ForEach(Array(Presets.palette.enumerated()), id: \.offset) { _, preset in
                        ColorSwatch(
                            color: preset,
                            isSelected: isCurrent(preset),
                            isEnabled: controller.isOn,
                            action: { controller.applyPreset(preset) }
                        )
                        .frame(height: 34)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(strings.customColor) {
                HSVColorPicker(
                    hue: controller.hsv.hue,
                    saturation: controller.hsv.saturation,
                    brightness: controller.hsv.brightness,
                    isEnabled: controller.isOn,
                    onHueChange: { controller.setHue($0) },
                    onSaturationValueChange: { controller.setSaturationValue(saturation: $0, brightness: $1) }
                )
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(strings.controlTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onOpenSettings) {
                    Label(strings.settingsTitle, systemImage: "gearshape")
                }
            }
        }
    }

    private func isCurrent(_ preset: HSVColor) -> Bool {
        abs(controller.hsv.hue - preset.hue) < 1
            && abs(controller.hsv.saturation - preset.saturation) < 0.01
            && abs(controller.hsv.brightness - preset.brightness) < 0.01
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText).font(.subheadline.weight(.medium))
                if let bound = controller.boundDevice {
                    Text(bound.name ?? bound.id.uuidString.prefix(8) + "…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private var statusColor: Color {
        switch controller.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .failed: return .red
        case .disconnected: return .gray
        }
    }

    private var statusText: String {
        switch controller.connectionState {
        case .connected: return strings.connected
        case .connecting: return strings.connecting
        case .failed: return strings.offline
        case .disconnected: return strings.offline
        }
    }
}

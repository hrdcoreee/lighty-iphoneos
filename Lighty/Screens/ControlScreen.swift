import SwiftUI

/// Main strip control: on/off, brightness, presets and the HSV picker, laid out
/// as glass cards over the ambient wash.
struct ControlScreen: View {
    @EnvironmentObject private var controller: LightyController

    let strings: Strings
    let onOpenSettings: () -> Void

    var body: some View {
        SolariumScaffold {
            SolariumHeader(title: strings.controlTitle, subtitle: statusText) {
                powerButton
            }

            SolariumCard {
                statusRow
            }

            SolariumCard(strings.brightnessLabel) {
                brightnessRow
            }

            SolariumCard(strings.quickColors) {
                presetGrid
            }

            SolariumCard(strings.customColor) {
                HSVColorPicker(
                    hue: controller.hsv.hue,
                    saturation: controller.hsv.saturation,
                    brightness: controller.hsv.brightness,
                    isEnabled: controller.isOn,
                    onHueChange: { controller.setHue($0) },
                    onSaturationValueChange: {
                        controller.setSaturationValue(saturation: $0, brightness: $1)
                    }
                )
                .padding(.top, 4)
            }
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
    }

    private var powerButton: some View {
        Button {
            controller.togglePower()
        } label: {
            Image(systemName: "power")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(controller.isOn ? Color.white : Color.secondary)
                .background {
                    if controller.isOn {
                        Circle().fill(Color.accentColor)
                    }
                }
        }
        .buttonStyle(.plain)
        .glassSurface(cornerRadius: 22, tint: controller.isOn ? .accentColor : nil)
        .disabled(controller.boundDevice == nil)
        .accessibilityLabel(strings.powerLabel)
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.subheadline.weight(.medium))
                if let bound = controller.boundDevice {
                    Text(bound.name ?? bound.id.uuidString.prefix(8) + "...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Text(controller.isOn ? strings.powerLabel : strings.offline)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var brightnessRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.min")
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { controller.hsv.brightness },
                    set: { controller.setBrightness($0) }
                ),
                in: 0.05...1
            )
            .tint(Color(hue: controller.hsv.hue / 360, saturation: 0.75, brightness: 1))
            .disabled(!controller.isOn)
            Image(systemName: "sun.max")
                .foregroundStyle(.secondary)
        }
    }

    private var presetGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
            spacing: 10
        ) {
            ForEach(Array(Presets.palette.enumerated()), id: \.offset) { _, preset in
                ColorSwatch(
                    color: preset,
                    isSelected: isCurrent(preset),
                    isEnabled: controller.isOn,
                    action: { controller.applyPreset(preset) }
                )
                .frame(height: 36)
            }
        }
    }

    private func isCurrent(_ preset: HSVColor) -> Bool {
        abs(controller.hsv.hue - preset.hue) < 1
            && abs(controller.hsv.saturation - preset.saturation) < 0.01
            && abs(controller.hsv.brightness - preset.brightness) < 0.01
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
        case .failed, .disconnected: return strings.offline
        }
    }
}

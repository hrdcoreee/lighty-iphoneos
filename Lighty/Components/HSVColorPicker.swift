import SwiftUI

/// Two-axis HSV picker ported from the Android `HsvColorPicker`.
///
/// The axes are intentionally decoupled: the saturation/brightness square only
/// reports `onSaturationValueChange` and the hue bar only reports `onHueChange`,
/// so adjusting one dimension cannot drag the other back to a stale value.
struct HSVColorPicker: View {
    let hue: Double
    let saturation: Double
    let brightness: Double
    let isEnabled: Bool
    let onHueChange: (Double) -> Void
    let onSaturationValueChange: (Double, Double) -> Void

    var body: some View {
        VStack(spacing: 20) {
            SaturationValuePanel(
                hue: hue,
                saturation: saturation,
                brightness: brightness,
                isEnabled: isEnabled,
                onChange: onSaturationValueChange
            )
            .aspectRatio(1.35, contentMode: .fit)

            HueBar(hue: hue, isEnabled: isEnabled, onHueChange: onHueChange)
                .frame(height: 36)
        }
    }
}

private struct SaturationValuePanel: View {
    let hue: Double
    let saturation: Double
    let brightness: Double
    let isEnabled: Bool
    let onChange: (Double, Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [.white, HSVColor(hue: hue, saturation: 1, brightness: 1).swiftUIColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )

                let x = min(max(saturation, 0), 1) * size.width
                let y = (1 - min(max(brightness, 0), 1)) * size.height

                Thumb(fill: HSVColor(hue: hue, saturation: saturation, brightness: brightness).swiftUIColor)
                    .position(x: x, y: y)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(isEnabled ? 0.4 : 0.15), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size))
            .opacity(isEnabled ? 1 : 0.6)
        }
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isEnabled, size.width > 0, size.height > 0 else { return }
                let s = min(max(value.location.x / size.width, 0), 1)
                let v = min(max(1 - value.location.y / size.height, 0), 1)
                onChange(Double(s), Double(v))
            }
    }
}

private struct HueBar: View {
    let hue: Double
    let isEnabled: Bool
    let onHueChange: (Double) -> Void

    private var spectrum: [Color] {
        stride(from: 0.0, through: 360.0, by: 60.0)
            .map { HSVColor(hue: $0, saturation: 1, brightness: 1).swiftUIColor }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: spectrum, startPoint: .leading, endPoint: .trailing)

                Thumb(fill: HSVColor(hue: hue, saturation: 1, brightness: 1).swiftUIColor)
                    .position(x: CGFloat(min(max(hue / 360, 0), 1)) * size.width, y: size.height / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(isEnabled ? 0.4 : 0.15), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled, size.width > 0 else { return }
                        onHueChange(Double(min(max(value.location.x / size.width, 0), 1)) * 360)
                    }
            )
            .opacity(isEnabled ? 1 : 0.6)
        }
    }
}

/// White ring plus a filled dot, matching the Android `drawThumb` helper.
private struct Thumb: View {
    let fill: Color

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.25)).frame(width: 28, height: 28)
            Circle().strokeBorder(Color.white, lineWidth: 3).frame(width: 24, height: 24)
            Circle().fill(fill).frame(width: 18, height: 18)
        }
    }
}

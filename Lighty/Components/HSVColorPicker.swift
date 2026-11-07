import SwiftUI

/// Two-axis HSV picker ported from the Android `HsvColorPicker`.
///
/// The axes are intentionally decoupled: the saturation/brightness square only
/// reports `onSaturationValueChange` and the hue bar only reports `onHueChange`,
/// so adjusting one dimension cannot drag the other back to a stale value.
///
/// Gesture policy is shared by both axes: nothing is reported on touch-down.
/// A press that moves is followed from the moment it passes `slop`, and a press
/// that never moves is applied on release. Touch-down is deliberately excluded
/// because a swipe to the home screen starts with exactly such a touch, and the
/// system only cancels it a few frames later - by then the strip would already
/// have changed color. `slop` is small enough that dragging still feels direct.
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

/// Travel needed before a press turns into a drag. It only delays the very
/// first frames of a press, so dragging still tracks the finger closely, while
/// the touch-down of a system swipe never reports a value.
private enum PickerGesture {
    static let slop: CGFloat = 6
}

private struct SaturationValuePanel: View {
    let hue: Double
    let saturation: Double
    let brightness: Double
    let isEnabled: Bool
    let onChange: (Double, Double) -> Void

    @State private var isDragging = false

    private let thumbRadius: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let insetW = max(size.width - thumbRadius * 2, 1)
            let insetH = max(size.height - thumbRadius * 2, 1)

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

                let x = thumbRadius + min(max(saturation, 0), 1) * insetW
                let y = thumbRadius + (1 - min(max(brightness, 0), 1)) * insetH

                Thumb(fill: HSVColor(hue: hue, saturation: saturation, brightness: brightness).swiftUIColor)
                    .position(x: x, y: y)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .gesture(gesture(in: size))
            .opacity(isEnabled ? 1 : 0.6)
        }
    }

    private func gesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isEnabled, size.width > 0, size.height > 0 else { return }
                if !isDragging {
                    let moved = abs(value.translation.width) >= PickerGesture.slop
                        || abs(value.translation.height) >= PickerGesture.slop
                    guard moved else { return }
                    isDragging = true
                }
                report(value.location, in: size)
            }
            .onEnded { value in
                defer { isDragging = false }
                // A press without movement is a tap; apply it on release.
                guard !isDragging, isEnabled, size.width > 0, size.height > 0 else { return }
                report(value.location, in: size)
            }
    }

    private func report(_ point: CGPoint, in size: CGSize) {
        let insetW = max(size.width - thumbRadius * 2, 1)
        let insetH = max(size.height - thumbRadius * 2, 1)
        let s = min(max((point.x - thumbRadius) / insetW, 0), 1)
        let v = min(max(1 - (point.y - thumbRadius) / insetH, 0), 1)
        onChange(Double(s), Double(v))
    }
}

private struct HueBar: View {
    let hue: Double
    let isEnabled: Bool
    let onHueChange: (Double) -> Void

    @State private var isDragging = false

    private var spectrum: [Color] {
        stride(from: 0.0, through: 360.0, by: 60.0)
            .map { HSVColor(hue: $0, saturation: 1, brightness: 1).swiftUIColor }
    }

    private let thumbRadius: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let insetW = max(size.width - thumbRadius * 2, 1)

            ZStack(alignment: .topLeading) {
                LinearGradient(colors: spectrum, startPoint: .leading, endPoint: .trailing)

                let x = thumbRadius + CGFloat(min(max(hue / 360, 0), 1)) * insetW
                Thumb(fill: HSVColor(hue: hue, saturation: 1, brightness: 1).swiftUIColor)
                    .position(x: x, y: size.height / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .gesture(gesture(in: size))
            .opacity(isEnabled ? 1 : 0.6)
        }
    }

    private func gesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isEnabled, size.width > 0 else { return }
                if !isDragging {
                    let moved = abs(value.translation.width) >= PickerGesture.slop
                        || abs(value.translation.height) >= PickerGesture.slop
                    guard moved else { return }
                    isDragging = true
                }
                report(value.location, in: size)
            }
            .onEnded { value in
                defer { isDragging = false }
                guard !isDragging, isEnabled, size.width > 0 else { return }
                report(value.location, in: size)
            }
    }

    private func report(_ point: CGPoint, in size: CGSize) {
        let insetW = max(size.width - thumbRadius * 2, 1)
        let fraction = min(max((point.x - thumbRadius) / insetW, 0), 1)
        onHueChange(Double(fraction) * 360)
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

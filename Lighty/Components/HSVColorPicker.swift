import SwiftUI

/// Two-axis HSV picker ported from the Android `HsvColorPicker`.
///
/// The axes are intentionally decoupled: the saturation/brightness square only
/// reports `onSaturationValueChange` and the hue bar only reports `onHueChange`,
/// so adjusting one dimension cannot drag the other back to a stale value.
///
/// Touch handling: a drag that begins in the system home strip is ignored
/// entirely, and a drag only reports once it has travelled past `slop`. Without
/// that, the touch-down of a swipe-to-home lands on the picker and recolors the
/// strip before the system claims the gesture.
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

/// Shared rule for both axes: the gesture starts by being ignored, and only
/// becomes active after the travel threshold, from a touch that did not begin
/// in the home strip.
private struct PickerDragState {
    /// Points a finger must travel before the picker starts following it. Large
    /// enough to reject the first frames of the home swipe, small enough to be
    /// imperceptible when actually dragging on purpose.
    static let slop: CGFloat = 12

    /// `frame` is the control's frame in the global coordinate space, which is
    /// what `DragGesture` locations must be added to before the strip test.
    static func shouldBegin(_ value: DragGesture.Value, globalFrame: CGRect) -> Bool {
        // Travel first: it is the cheap test and rejects the touch-down frame.
        guard abs(value.translation.width) >= slop || abs(value.translation.height) >= slop else {
            return false
        }
        let globalStartY = globalFrame.minY + value.startLocation.y
        return !WindowMetrics.isInHomeStrip(globalY: globalStartY)
    }
}

private struct SaturationValuePanel: View {
    let hue: Double
    let saturation: Double
    let brightness: Double
    let isEnabled: Bool
    let onChange: (Double, Double) -> Void

    @State private var isTracking = false

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
            // A tap applies the color on release, never on touch-down: if the
            // touch turns out to be a home swipe the system cancels it first.
            .simultaneousGesture(tapGesture(in: size, globalFrame: geometry.frame(in: .global)))
            .gesture(dragGesture(size: size, globalFrame: geometry.frame(in: .global)))
            .opacity(isEnabled ? 1 : 0.6)
        }
    }

    private func dragGesture(size: CGSize, globalFrame: CGRect) -> some Gesture {
        // `minimumDistance: 0` is required so a tap-drag updates the thumb from
        // the first reported frame; the home-strip and slop rules in
        // `PickerDragState` reject the touch-down of a system swipe instead.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isEnabled, size.width > 0, size.height > 0 else { return }
                if !isTracking {
                    guard PickerDragState.shouldBegin(value, globalFrame: globalFrame) else { return }
                    isTracking = true
                    // Start from the finger's own position, not the old thumb.
                    report(value.location, in: size)
                    return
                }
                report(value.location, in: size)
            }
            .onEnded { _ in isTracking = false }
    }

    private func tapGesture(in size: CGSize, globalFrame: CGRect) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard isEnabled, size.width > 0, size.height > 0 else { return }
                let globalY = globalFrame.minY + value.location.y
                guard !WindowMetrics.isInHomeStrip(globalY: globalY) else { return }
                report(value.location, in: size)
            }
    }

    private func report(_ point: CGPoint, in size: CGSize) {
        let s = min(max(point.x / size.width, 0), 1)
        let v = min(max(1 - point.y / size.height, 0), 1)
        onChange(Double(s), Double(v))
    }
}

private struct HueBar: View {
    let hue: Double
    let isEnabled: Bool
    let onHueChange: (Double) -> Void

    @State private var isTracking = false

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
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard isEnabled, size.width > 0 else { return }
                        let globalY = geometry.frame(in: .global).minY + value.location.y
                        guard !WindowMetrics.isInHomeStrip(globalY: globalY) else { return }
                        onHueChange(Double(min(max(value.location.x / size.width, 0), 1)) * 360)
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled, size.width > 0 else { return }
                        if !isTracking {
                            guard PickerDragState.shouldBegin(
                                value,
                                globalFrame: geometry.frame(in: .global)
                            ) else { return }
                            isTracking = true
                        }
                        onHueChange(Double(min(max(value.location.x / size.width, 0), 1)) * 360)
                    }
                    .onEnded { _ in isTracking = false }
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

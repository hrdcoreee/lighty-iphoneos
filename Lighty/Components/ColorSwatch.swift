import SwiftUI

/// Converts the app's `HSVColor` into a SwiftUI `Color`.
extension HSVColor {
    var swiftUIColor: Color {
        let components = rgb
        return Color(
            .sRGB,
            red: Double(components.r) / 255,
            green: Double(components.g) / 255,
            blue: Double(components.b) / 255,
            opacity: 1
        )
    }
}

/// A round tappable color swatch used by the preset grid.
struct ColorSwatch: View {
    let color: HSVColor
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.swiftUIColor)
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? Color.white : Color.white.opacity(0.25),
                        lineWidth: isSelected ? 2.5 : 0.8
                    )
                )
                .shadow(
                    color: isSelected ? color.swiftUIColor.opacity(0.55) : Color.black.opacity(0.20),
                    radius: isSelected ? 6 : 3,
                    x: 0,
                    y: 1.5
                )
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .animation(.spring(response: 0.25), value: isSelected)
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text("Color preset"))
    }
}

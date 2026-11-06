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
                        isSelected ? Color.primary : Color.primary.opacity(0.15),
                        lineWidth: isSelected ? 3 : 1
                    )
                )
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text("Color preset"))
    }
}

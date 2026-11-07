import SwiftUI

/// Design tokens for the "solarium" look: bright, airy surfaces floating over a
/// slowly drifting color wash, strictly following Apple Human Interface Guidelines.
enum SolariumTheme {

    /// Standard Apple grouped card corner radius (continuous squircle).
    static let cornerRadius: CGFloat = 16

    /// Padding inside a card (Apple standard).
    static let cardPadding: CGFloat = 16

    /// Vertical space between grouped cards.
    static let cardSpacing: CGFloat = 14

    /// Blob colors of the ambient background.
    static func washColors(for scheme: ColorScheme) -> [Color] {
        switch scheme {
        case .dark:
            return [
                Color(red: 0.22, green: 0.32, blue: 0.75),
                Color(red: 0.55, green: 0.22, blue: 0.68),
                Color(red: 0.12, green: 0.55, blue: 0.62),
            ]
        default:
            return [
                Color(red: 0.51, green: 0.62, blue: 0.98),
                Color(red: 0.86, green: 0.55, blue: 0.95),
                Color(red: 0.45, green: 0.88, blue: 0.85),
            ]
        }
    }

    static func baseColor(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.06, green: 0.07, blue: 0.11)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }
}

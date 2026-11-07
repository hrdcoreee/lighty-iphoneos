import SwiftUI

/// Design tokens for the "solarium" look: bright, airy surfaces floating over a
/// slowly drifting color wash.
enum SolariumTheme {

    /// Card corner radius. Matches the picker corners so the screen reads as one
    /// system rather than a list with rounded boxes in it.
    static let cornerRadius: CGFloat = 22

    /// Padding inside a card.
    static let cardPadding: CGFloat = 14

    /// Vertical space between cards.
    static let cardSpacing: CGFloat = 12

    /// Blob colors of the ambient background.
    static func washColors(for scheme: ColorScheme) -> [Color] {
        switch scheme {
        case .dark:
            return [
                Color(red: 0.20, green: 0.28, blue: 0.62),
                Color(red: 0.44, green: 0.18, blue: 0.52),
                Color(red: 0.10, green: 0.42, blue: 0.48),
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
            ? Color(red: 0.05, green: 0.06, blue: 0.09)
            : Color(red: 0.97, green: 0.97, blue: 0.99)
    }
}

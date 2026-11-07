import UIKit

/// Read-only geometry of the key window, used where SwiftUI would otherwise
/// report a different coordinate space (scroll views, sheets, overlays).
@MainActor
enum WindowMetrics {

    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    static var screenHeight: CGFloat { keyWindow?.bounds.height ?? 0 }

    static var bottomInset: CGFloat { keyWindow?.safeAreaInsets.bottom ?? 0 }

    /// True when a point in global/window coordinates lies in the home strip.
    static func isInHomeStrip(globalY: CGFloat) -> Bool {
        HomeStripGeometry.contains(
            globalY: globalY,
            screenHeight: screenHeight,
            bottomInset: bottomInset
        )
    }
}

import CoreGraphics

/// Geometry of the system "home gesture" strip at the bottom of the screen.
///
/// A swipe to the home screen starts with a touch in that strip. iOS hands that
/// touch to the app first and only then claims the gesture, so any control that
/// reacts on touch-down (a color picker dragged with `minimumDistance: 0`) fires
/// before the system cancels it. Content must therefore treat the strip as
/// belonging to the system.
///
/// Kept free of UIKit so the rule is unit tested on CI.
enum HomeStripGeometry {

    /// Even without a home indicator (or while the inset is still zero) the
    /// bottommost points belong to the system's edge-swipe area.
    static let minimumInset: CGFloat = 20

    /// Height of the strip measured from the very bottom of the screen.
    static func exclusionHeight(bottomInset: CGFloat) -> CGFloat {
        max(bottomInset, minimumInset)
    }

    /// True when a touch that started at `globalY` belongs to the system.
    static func contains(globalY: CGFloat, screenHeight: CGFloat, bottomInset: CGFloat) -> Bool {
        guard screenHeight > 0, globalY.isFinite else { return false }
        let threshold = screenHeight - exclusionHeight(bottomInset: bottomInset)
        return globalY >= threshold
    }
}

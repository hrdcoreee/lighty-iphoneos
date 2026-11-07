import CoreGraphics

/// Geometry of the system "home gesture" strip at the bottom of the screen.
///
/// A swipe to the home screen starts with a touch in that strip. iOS hands the
/// touch to the app first and only then claims the gesture, so a control that
/// reacts on touch-down fires before the swipe is cancelled. Content should
/// therefore treat the strip as belonging to the system.
///
/// The strip exists exactly where the home indicator does, which is what the
/// bottom safe-area inset reports. On devices with a physical home button that
/// inset is zero and nothing is blocked, so the last rows of a list stay fully
/// usable.
///
/// Kept free of UIKit so the rule is unit tested on CI.
enum HomeStripGeometry {

    /// Height of the strip measured from the very bottom of the screen.
    static func exclusionHeight(bottomInset: CGFloat) -> CGFloat {
        bottomInset > 0 && bottomInset.isFinite ? bottomInset : 0
    }

    /// True when a touch that started at `globalY` belongs to the system.
    static func contains(globalY: CGFloat, screenHeight: CGFloat, bottomInset: CGFloat) -> Bool {
        guard screenHeight > 0, globalY.isFinite else { return false }
        let height = exclusionHeight(bottomInset: bottomInset)
        guard height > 0 else { return false }
        return globalY >= screenHeight - height
    }
}

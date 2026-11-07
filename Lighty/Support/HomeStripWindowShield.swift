import UIKit

/// Transparent shield over the home-indicator strip of the key window.
///
/// Why this exists: a swipe to the home screen starts with a touch in the
/// bottom strip. iOS gives that touch to the app first and only then claims the
/// gesture, so any SwiftUI control that reacts on touch-down (the color picker
/// did) fires before the swipe is cancelled. The result was a strip that
/// silently changed color on the way home.
///
/// Why not a SwiftUI overlay: a `List`/`ScrollView` installs its own hit
/// testing, and an overlay drawn inside the safe area never covers the strip.
/// A plain `UIView` in the window, sized from the real window bounds, cannot be
/// scrolled past and is above the whole SwiftUI hierarchy.
///
/// The view is a full-window container that only claims touches inside the
/// strip; everywhere else `hitTest` returns `nil`, so nothing else changes.
/// It carries no recognisers, so the system's own swipe-to-home is untouched.
@MainActor
final class HomeStripWindowShield: UIView {

    private static weak var installed: HomeStripWindowShield?

    /// Area that receives touches. Everything else passes straight through.
    private var strip: CGRect = .zero

    /// Installs the shield into the key window. Safe to call repeatedly; a
    /// later call only re-attaches it if the window changed.
    static func install() {
        guard let window = WindowMetrics.keyWindow else { return }

        if let shield = installed {
            if shield.superview !== window {
                shield.removeFromSuperview()
                window.addSubview(shield)
                shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                shield.frame = window.bounds
            }
            reposition(shield, in: window)
            shield.setNeedsLayout()
            return
        }

        let shield = HomeStripWindowShield(frame: window.bounds)
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shield.isUserInteractionEnabled = true
        shield.backgroundColor = .clear
        shield.isAccessibilityElement = false
        shield.accessibilityElementsHidden = true
        // Added last so it sits above the SwiftUI hosting controller. Alerts
        // and sheets live in their own windows, so they keep working.
        window.addSubview(shield)
        reposition(shield, in: window)
        installed = shield
    }

    /// Keeps the shield above the app content. Presentations over it are handled
    /// in `hitTest`, which steps aside while a sheet is up.
    private static func reposition(_ shield: HomeStripWindowShield, in window: UIWindow) {
        window.bringSubviewToFront(shield)
    }

    static func refreshFrame() {
        guard let shield = installed else { return }
        shield.setNeedsLayout()
        shield.layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Reading the container's own `safeAreaInsets` keeps this correct across
        // rotation and split-view changes, without any observation plumbing.
        let height = HomeStripGeometry.exclusionHeight(bottomInset: safeAreaInsets.bottom)
        strip = CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
    }

    /// Only the strip claims a touch; every other point falls through to the
    /// SwiftUI content below.
    ///
    /// While a sheet is presented the shield steps aside: the sheet is drawn in
    /// the same window and reaches the bottom edge, so blocking there would
    /// make the last rows of its list unreachable.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !strip.isEmpty, strip.contains(point) else { return nil }
        guard window?.rootViewController?.presentedViewController == nil else { return nil }
        return self
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        !strip.isEmpty && strip.contains(point)
    }
}

import SwiftUI

/// Transparent strip over the home-indicator area that swallows touches.
///
/// iOS delivers the touch-down of a swipe-to-home to the app before the system
/// claims the gesture. That first frame used to land on the content underneath,
/// which on the control screen is the color picker, so swiping home silently
/// changed the strip color. The shield absorbs that touch instead.
///
/// It carries no gesture recognisers on purpose: hit testing alone stops the
/// touch at this view, and with nothing to recognise the system's own
/// swipe-to-home gesture is left completely untouched.
struct TouchShield: View {

    /// Bottom safe-area inset of the window, in points. `0` on devices with a
    /// physical home button, where the strip does not exist and content is
    /// allowed to reach the bottom edge.
    let height: CGFloat

    var body: some View {
        if height > 0 {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: height)
                // The touch is captured here and simply goes nowhere: there is
                // no gesture to fire, and no fall-through to the content below.
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
    }
}


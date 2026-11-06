import SwiftUI

/// Transparent strip over the home-indicator area that swallows touches.
///
/// iOS delivers the touch-down of a swipe-to-home to the app before the system
/// claims the gesture. That first frame used to land on the content underneath,
/// which on the control screen is the color picker, so swiping home silently
/// changed the strip color. The shield absorbs that touch instead.
///
/// Occlusion is what blocks the touch: the strip is hit-testable, so the event
/// stops here instead of reaching the picker below. The tap handler is a no-op
/// that exists only to make that absorption explicit; no drag recogniser is
/// attached, so the system's own swipe-to-home gesture is untouched.
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
                // The touch is captured here and goes nowhere: the no-op tap
                // replaces "tap the picker underneath", and nothing falls
                // through, because this view wins the hit test.
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)
        }
    }
}


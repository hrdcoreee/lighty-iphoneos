import SwiftUI

/// Ambient backdrop: a base color with three large, slow-moving color blobs.
///
/// Everything else in the app floats above this, which is what gives the glass
/// cards something to refract and keeps the screen from reading as a flat list.
/// Motion is deliberately very slow and is disabled under Reduce Motion.
struct SolariumBackground: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drift: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let colors = SolariumTheme.washColors(for: scheme)

            ZStack {
                SolariumTheme.baseColor(for: scheme)

                blob(colors[0], size: size, x: 0.15, y: 0.10, radius: 0.62)
                blob(colors[1], size: size, x: 0.85, y: 0.32, radius: 0.55)
                blob(colors[2], size: size, x: 0.45, y: 0.88, radius: 0.60)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                drift = 1
            }
        }
    }

    private func blob(
        _ color: Color,
        size: CGSize,
        x: CGFloat,
        y: CGFloat,
        radius: CGFloat
    ) -> some View {
        let diameter = min(size.width, size.height) * radius
        let wobble = reduceMotion ? 0 : 26
        return Circle()
            .fill(color.opacity(scheme == .dark ? 0.55 : 0.45))
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter * 0.30)
            .offset(
                x: size.width * x - diameter / 2 + drift * wobble,
                y: size.height * y - diameter / 2 - drift * wobble
            )
    }
}

import SwiftUI

/// Ambient backdrop: a base color with three large, slow-moving color blobs.
///
/// Everything else in the app floats above this, which is what gives the glass
/// cards something to refract and keeps the screen from reading as a flat list.
/// Motion is deliberately very slow and is disabled under Reduce Motion.
///
/// Every offset is computed into an explicitly typed constant before it reaches
/// a modifier. Building the same arithmetic inline made the Swift type checker
/// time out on the CI toolchain.
struct SolariumBackground: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drift: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = proxy.size
            let colors: [Color] = SolariumTheme.washColors(for: scheme)

            ZStack {
                SolariumTheme.baseColor(for: scheme)

                blob(colors[0], size: size, x: 0.20, y: 0.15, radius: 0.85)
                blob(colors[1], size: size, x: 0.80, y: 0.45, radius: 0.80)
                blob(colors[2], size: size, x: 0.35, y: 0.80, radius: 0.90)
            }
            .ignoresSafeArea()
        }
        .onAppear(perform: startDrift)
    }

    private func startDrift() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
            drift = 1
        }
    }

    private func blob(
        _ color: Color,
        size: CGSize,
        x: CGFloat,
        y: CGFloat,
        radius: CGFloat
    ) -> some View {
        let diameter: CGFloat = min(size.width, size.height) * radius
        let opacity: Double = scheme == .dark ? 0.65 : 0.45
        let blurRadius: CGFloat = diameter * 0.35
        let wobble: CGFloat = reduceMotion ? 0 : 26
        let travel: CGFloat = drift * wobble
        let offsetX: CGFloat = (size.width * x) - (diameter / 2) + travel
        let offsetY: CGFloat = (size.height * y) - (diameter / 2) - travel

        return Circle()
            .fill(color.opacity(opacity))
            .frame(width: diameter, height: diameter)
            .blur(radius: blurRadius)
            .offset(x: offsetX, y: offsetY)
    }
}
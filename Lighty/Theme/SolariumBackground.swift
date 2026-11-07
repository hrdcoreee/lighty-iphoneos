import SwiftUI

/// Ambient backdrop: a rich, vibrant gradient wash with deep luminous glows.
///
/// This provides the optical color source that liquid glass refracts and transmits.
/// Motion is slow and organic, disabled under Reduce Motion.
struct SolariumBackground: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drift: CGFloat = 0

    var body: some View {
        ZStack {
            if scheme == .dark {
                // Deep midnight canvas
                Color(red: 0.04, green: 0.05, blue: 0.09)

                // Top-leading luminous sapphire aura
                RadialGradient(
                    colors: [
                        Color(red: 0.22, green: 0.38, blue: 0.95).opacity(0.70),
                        Color(red: 0.15, green: 0.25, blue: 0.70).opacity(0.35),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.15 + drift * 0.1, y: 0.12 - drift * 0.06),
                    startRadius: 20,
                    endRadius: 420
                )

                // Mid-trailing warm violet/magenta aura
                RadialGradient(
                    colors: [
                        Color(red: 0.72, green: 0.18, blue: 0.75).opacity(0.60),
                        Color(red: 0.45, green: 0.10, blue: 0.55).opacity(0.30),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.88 - drift * 0.08, y: 0.42 + drift * 0.08),
                    startRadius: 20,
                    endRadius: 400
                )

                // Bottom-leading electric teal aura
                RadialGradient(
                    colors: [
                        Color(red: 0.10, green: 0.65, blue: 0.75).opacity(0.55),
                        Color(red: 0.05, green: 0.40, blue: 0.50).opacity(0.25),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.30 + drift * 0.06, y: 0.88 - drift * 0.08),
                    startRadius: 20,
                    endRadius: 420
                )
            } else {
                // Light mode: airy crystal canvas
                Color(red: 0.95, green: 0.96, blue: 0.98)

                RadialGradient(
                    colors: [
                        Color(red: 0.55, green: 0.70, blue: 1.0).opacity(0.55),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.15 + drift * 0.1, y: 0.12),
                    startRadius: 40,
                    endRadius: 420
                )

                RadialGradient(
                    colors: [
                        Color(red: 0.90, green: 0.60, blue: 0.95).opacity(0.50),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.85 - drift * 0.08, y: 0.40),
                    startRadius: 40,
                    endRadius: 400
                )

                RadialGradient(
                    colors: [
                        Color(red: 0.45, green: 0.90, blue: 0.85).opacity(0.45),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.30, y: 0.85),
                    startRadius: 40,
                    endRadius: 400
                )
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: startDrift)
    }

    private func startDrift() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
            drift = 1
        }
    }
}
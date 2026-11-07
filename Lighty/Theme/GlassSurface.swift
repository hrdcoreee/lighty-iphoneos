import SwiftUI

/// A rounded, translucent surface.
///
/// On iOS 26 and later this is the real Liquid Glass material
/// (`glassEffect(_:in:)`), so it refracts and highlights like the system
/// controls. On iOS 16-25 the API does not exist, so the same shape is drawn
/// with `.ultraThinMaterial`, a hairline border and an inner highlight; the
/// result is deliberately close, but it is a simulation and is documented as
/// such rather than pretended to be identical.
struct GlassSurface: ViewModifier {

    var cornerRadius: CGFloat = SolariumTheme.cornerRadius
    var tint: Color? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Apply the effect to the content itself: this keeps the glass
            // shape tied to the card bounds and avoids a transparent
            // rectangle sitting behind it just to carry the material.
            content
                .glassEffect(
                    .regular.tint(tint?.opacity(0.35)),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            content
                .background { glassBackground }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    // Liquid Glass 3D specular rim: sharp light catch top-left, subtle rim bottom-right
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.50), location: 0.0),
                                    .init(color: .white.opacity(0.18), location: 0.25),
                                    .init(color: .white.opacity(0.04), location: 0.60),
                                    .init(color: .white.opacity(0.28), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: .black.opacity(0.18),
                    radius: 16,
                    x: 0,
                    y: 8
                )
                .shadow(
                    color: .black.opacity(0.08),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        }
    }

    @ViewBuilder
    private var glassBackground: some View {
        ZStack {
            if PrivateGlassAPI.isBackdropAvailable {
                BackdropGlassView(
                    cornerRadius: cornerRadius,
                    edgeBand: min(12, cornerRadius),
                    displacement: 12,
                    blurRadius: 16,
                    saturation: 1.30,
                    useTelegramMatrix: true,
                    tint: tint.map { UIColor($0).withAlphaComponent(0.15) } ?? UIColor(white: 1.0, alpha: 0.06)
                )
            } else {
                fallbackSurface
            }

            // Delicate top surface reflection
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.10), .white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.35)
                    )
                )
        }
    }

    private var fallbackSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            if let tint {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(0.18))
            }
            // A soft highlight along the top edge, which is what makes the
            // simulated surface read as glass rather than as a blur.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blendMode(.plusLighter)
        }
    }
}

extension View {
    /// Wraps the view in a glass card.
    func glassSurface(
        cornerRadius: CGFloat = SolariumTheme.cornerRadius,
        tint: Color? = nil
    ) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint))
    }
}
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
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.12),
                                    .white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(
                    color: .black.opacity(0.10),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        }
    }

    @ViewBuilder
    private var glassBackground: some View {
        if PrivateGlassAPI.isBackdropAvailable {
            BackdropGlassView(
                cornerRadius: cornerRadius,
                edgeBand: min(10, cornerRadius),
                displacement: 10,
                blurRadius: 18,
                saturation: 1.25,
                useTelegramMatrix: true,
                tint: tint.map { UIColor($0).withAlphaComponent(0.10) } ?? UIColor(white: 1.0, alpha: 0.04)
            )
        } else {
            fallbackSurface
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
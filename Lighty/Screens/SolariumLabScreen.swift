import SwiftUI

/// On-device lab for the private-backdrop glass.
///
/// This is a development screen, not a product surface: the sliders exist so
/// the mesh can be tuned on the actual device, where the backdrop layer either
/// works or silently samples nothing. The capability row reports what the
/// runtime found so a screenshot is enough to diagnose a failure.
struct SolariumLabScreen: View {

    @State private var cornerRadius: Double = 22
    @State private var edgeBand: Double = 16
    @State private var displacement: Double = 14
    @State private var blurRadius: Double = 8
    @State private var saturation: Double = 1.35
    @State private var useBackdrop = true

    var body: some View {
        SolariumScaffold {
            SolariumHeader(
                title: "Solarium Lab",
                subtitle: useBackdrop ? "Private backdrop mesh" : "System material fallback"
            )

            capabilityCard
            previewCard
            controlsCard
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var capabilityCard: some View {
        SolariumCard("Runtime") {
            VStack(alignment: .leading, spacing: 6) {
                capabilityRow("CABackdropLayer", available: PrivateGlassAPI.isBackdropAvailable)
                capabilityRow("CAMutableMeshTransform", available: PrivateGlassAPI.isMeshAvailable)
                capabilityRow("CAFilter", available: PrivateGlassAPI.isFilterAvailable)
                Text("Availability is resolved at runtime; a missing class degrades instead of crashing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func capabilityRow(_ name: String, available: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(available ? .green : .red)
            Text(name)
                .font(.subheadline.monospaced())
            Spacer(minLength: 0)
            Text(available ? "yes" : "no")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Colorful content sits behind the panel so refraction and blur are both
    /// visible; a flat background would hide the effect entirely.
    private var previewCard: some View {
        SolariumCard("Preview") {
            ZStack {
                RefractionBackdrop()

                Group {
                    if useBackdrop {
                        BackdropGlassView(
                            cornerRadius: cornerRadius,
                            edgeBand: edgeBand,
                            displacement: displacement,
                            blurRadius: blurRadius,
                            saturation: saturation,
                            tint: UIColor.white.withAlphaComponent(0.06)
                        )
                    } else {
                        Color.clear.glassSurface(cornerRadius: cornerRadius)
                    }
                }
                .frame(height: 150)
                .overlay(
                    Text("Glass")
                        .font(.headline)
                        .foregroundStyle(.primary)
                )
                .padding(8)
            }
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var controlsCard: some View {
        SolariumCard("Mesh") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Private backdrop", isOn: $useBackdrop)
                    .font(.subheadline)

                slider("Corner radius", value: $cornerRadius, range: 0...44, format: "%.0f")
                slider("Edge band", value: $edgeBand, range: 2...40, format: "%.0f")
                slider("Displacement", value: $displacement, range: 0...32, format: "%.0f")
                slider("Blur radius", value: $blurRadius, range: 0...24, format: "%.1f")
                slider("Saturation", value: $saturation, range: 0.5...2.0, format: "%.2f")
            }
        }
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer(minLength: 0)
                Text(String(format: format, value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

/// Diagonal stripes in saturated colors, the classic test pattern for a
/// refraction: any bend of the image is immediately obvious as wavy stripes.
private struct RefractionBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { context, canvasSize in
                let stripeWidth: CGFloat = 18
                var index = 0
                var x = -canvasSize.height
                while x < canvasSize.width + canvasSize.height {
                    let hue = Double((index % 12)) / 12.0
                    let color = Color(hue: hue, saturation: 0.85, brightness: 0.95)
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + stripeWidth, y: 0))
                    path.addLine(to: CGPoint(x: x + stripeWidth + canvasSize.height, y: canvasSize.height))
                    path.addLine(to: CGPoint(x: x + canvasSize.height, y: canvasSize.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(color))
                    x += stripeWidth * 2
                    index += 1
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .background(Color.black)
    }
}
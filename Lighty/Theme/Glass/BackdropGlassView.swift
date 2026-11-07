import SwiftUI
import UIKit

/// A glass panel drawn with a private backdrop layer so the content behind it
/// is blurred *and* bent at the rim.
///
/// iOS 26 and later use the system material (`GlassSurface`); this view exists
/// for iOS 16-25, where no public refraction API is available.
struct BackdropGlassView: UIViewRepresentable {

    var cornerRadius: CGFloat
    var edgeBand: CGFloat
    var displacement: CGFloat
    var blurRadius: CGFloat
    var saturation: CGFloat
    var tint: UIColor?

    func makeUIView(context: Context) -> BackdropGlassUIView {
        BackdropGlassUIView()
    }

    func updateUIView(_ view: BackdropGlassUIView, context: Context) {
        view.apply(
            cornerRadius: cornerRadius,
            edgeBand: edgeBand,
            displacement: displacement,
            blurRadius: blurRadius,
            saturation: saturation,
            tint: tint
        )
    }
}

/// The UIKit half of `BackdropGlassView`.
///
/// A `CABackdropLayer` is added as a sublayer. Its mesh is expressed in the
/// layer's unit space, so it is rebuilt whenever the size or any of the mesh
/// parameters change.
final class BackdropGlassUIView: UIView {

    private struct MeshKey: Equatable {
        var size: CGSize
        var cornerRadius: CGFloat
        var edgeBand: CGFloat
        var displacement: CGFloat
    }

    private let backdropLayer: CALayer?
    private let tintLayer = CALayer()
    private let highlightLayer = CAGradientLayer()

    private var appliedKey: MeshKey?

    private var cornerRadius: CGFloat = 22
    private var edgeBand: CGFloat = 16
    private var displacement: CGFloat = 14
    private var blurRadius: CGFloat = 8
    private var saturation: CGFloat = 1.35
    private var tint: UIColor?

    override init(frame: CGRect) {
        self.backdropLayer = PrivateGlassAPI.makeBackdropLayer(scale: UIScreen.main.scale)
        super.init(frame: frame)

        backgroundColor = .clear
        isUserInteractionEnabled = false
        clipsToBounds = true

        if let backdropLayer {
            // Without a delegate that returns a null action, a backdrop layer
            // re-samples on every layout pass and flickers.
            backdropLayer.delegate = backdropDelegate
            layer.addSublayer(backdropLayer)
        }

        layer.addSublayer(tintLayer)

        // The system material gets this highlight for free; a bare backdrop
        // layer needs it drawn explicitly or the panel reads as a flat blur.
        highlightLayer.colors = [
            UIColor.white.withAlphaComponent(0.30).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
        ]
        highlightLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        highlightLayer.endPoint = CGPoint(x: 0.5, y: 0.62)
        layer.addSublayer(highlightLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var backdropDelegate = BackdropDelegate()

    private final class BackdropDelegate: NSObject, CALayerDelegate {
        func action(for layer: CALayer, forKey event: String) -> CAAction? { nil }
    }

    func apply(
        cornerRadius: CGFloat,
        edgeBand: CGFloat,
        displacement: CGFloat,
        blurRadius: CGFloat,
        saturation: CGFloat,
        tint: UIColor?
    ) {
        self.cornerRadius = cornerRadius
        self.edgeBand = edgeBand
        self.displacement = displacement
        self.blurRadius = blurRadius
        self.saturation = saturation
        self.tint = tint

        // Filters are cheap objects; recreating them on every update keeps the
        // code free of a "has anything really changed" cache that would have
        // to mirror every parameter.
        applyFilters()
        tintLayer.backgroundColor = (tint ?? .clear).cgColor
        setNeedsLayout()
    }

    private func applyFilters() {
        guard let backdropLayer else { return }

        var filters: [Any] = []

        if blurRadius > 0, let blur = PrivateGlassAPI.makeFilter("gaussianBlur") {
            blur.setValue(blurRadius as NSNumber, forKey: "inputRadius")
            filters.append(blur)
        }

        if saturation != 1,
           let matrix = PrivateGlassAPI.makeColorMatrixValue(saturationMatrix(saturation)),
           let colorMatrix = PrivateGlassAPI.makeFilter("colorMatrix") {
            colorMatrix.setValue(matrix, forKey: "inputColorMatrix")
            // Lets the filter scale with the backdrop instead of a snapshot.
            colorMatrix.setValue(true as NSNumber, forKey: "inputBackdropAware")
            filters.append(colorMatrix)
        }

        // `filters` is not exposed as a supported property on iOS; setting it
        // through KVC is the standard way this private filter array is used.
        backdropLayer.setValue(filters, forKey: "filters")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let bounds = self.bounds
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous

        backdropLayer?.frame = bounds
        tintLayer.frame = bounds
        tintLayer.cornerRadius = cornerRadius
        tintLayer.cornerCurve = .continuous
        tintLayer.masksToBounds = true
        highlightLayer.frame = bounds

        let key = MeshKey(
            size: bounds.size,
            cornerRadius: cornerRadius,
            edgeBand: edgeBand,
            displacement: displacement
        )
        guard key != appliedKey else { return }
        appliedKey = key
        rebuildMesh(size: bounds.size)
    }

    private func rebuildMesh(size: CGSize) {
        guard let backdropLayer, size.width > 0, size.height > 0 else { return }

        let parameters = GlassMeshGeometry.Parameters(
            cornerRadius: cornerRadius,
            edgeBand: edgeBand,
            displacement: displacement
        )
        let mesh = GlassMeshGeometry.makeMesh(size: size, parameters: parameters)

        guard let value = PrivateGlassAPI.makeMesh(vertices: mesh.vertices, faces: mesh.faces) else {
            return
        }
        guard PrivateGlassAPI.canApplyMesh(to: backdropLayer) else { return }
        PrivateGlassAPI.applyMesh(value, to: backdropLayer)
    }

    /// Saturation matrix in `CAColorMatrix` layout: four rows of five
    /// coefficients. The last column is the bias, left at zero.
    private func saturationMatrix(_ amount: CGFloat) -> [Float] {
        let luminanceR: Float = 0.2126
        let luminanceG: Float = 0.7152
        let luminanceB: Float = 0.0722
        let s = Float(amount)
        let inverse = 1 - s

        return [
            inverse * luminanceR + s, inverse * luminanceG, inverse * luminanceB, 0, 0,
            inverse * luminanceR, inverse * luminanceG + s, inverse * luminanceB, 0, 0,
            inverse * luminanceR, inverse * luminanceG, inverse * luminanceB + s, 0, 0,
            0, 0, 0, 1, 0,
        ]
    }
}
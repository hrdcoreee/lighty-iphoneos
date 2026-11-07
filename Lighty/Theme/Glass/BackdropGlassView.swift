import SwiftUI
import UIKit

/// A glass panel drawn with a private backdrop layer so the content behind it
/// is blurred *and* bent at the rim.
///
/// iOS 26 and later use the system material (`GlassSurface`); this view exists
/// for iOS 16-25, where no public refraction API is available.
struct BackdropGlassView: UIViewRepresentable {

    var cornerRadius: CGFloat = SolariumTheme.cornerRadius
    var edgeBand: CGFloat = 10
    var displacement: CGFloat = 10
    var blurRadius: CGFloat = 18
    var saturation: CGFloat = 1.25
    var useTelegramMatrix: Bool = true
    var tint: UIColor? = nil

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
            useTelegramMatrix: useTelegramMatrix,
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

    /// Telegram-tuned color matrix for rich liquid glass refraction:
    /// amplifies saturation, boosts color separation, and lifts brightness by 0.05.
    static let telegramColorMatrix: [Float] = [
        2.6705, -1.1088, -0.1117, 0.0, 0.05,
        -0.3295,  1.8914, -0.1119, 0.0, 0.05,
        -0.3297, -1.1084,  2.8881, 0.0, 0.05,
         0.0,     0.0,     0.0,   1.0, 0.0
    ]

    private struct MeshKey: Equatable {
        var size: CGSize
        var cornerRadius: CGFloat
        var edgeBand: CGFloat
        var displacement: CGFloat
    }

    private let backdropLayer: CALayer?
    private var fallbackBlurView: UIVisualEffectView?
    private let tintLayer = CALayer()
    private let highlightLayer = CAGradientLayer()

    private var appliedKey: MeshKey?

    private var cornerRadius: CGFloat = SolariumTheme.cornerRadius
    private var edgeBand: CGFloat = 10
    private var displacement: CGFloat = 10
    private var blurRadius: CGFloat = 18
    private var saturation: CGFloat = 1.25
    private var useTelegramMatrix: Bool = true
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
        } else {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            blur.isUserInteractionEnabled = false
            addSubview(blur)
            self.fallbackBlurView = blur
        }

        layer.addSublayer(tintLayer)

        // Subtle specular top edge in line with Apple HIG
        highlightLayer.colors = [
            UIColor.white.withAlphaComponent(0.08).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
        ]
        highlightLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        highlightLayer.endPoint = CGPoint(x: 0.5, y: 0.18)
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
        useTelegramMatrix: Bool = true,
        tint: UIColor?
    ) {
        let filtersChanged = (self.blurRadius != blurRadius ||
                              self.saturation != saturation ||
                              self.useTelegramMatrix != useTelegramMatrix)

        self.cornerRadius = cornerRadius
        self.edgeBand = edgeBand
        self.displacement = displacement
        self.blurRadius = blurRadius
        self.saturation = saturation
        self.useTelegramMatrix = useTelegramMatrix
        self.tint = tint

        if filtersChanged || (backdropLayer != nil && backdropLayer?.filters == nil) {
            applyFilters()
        }
        tintLayer.backgroundColor = (tint ?? .clear).cgColor
        setNeedsLayout()
    }

    private func applyFilters() {
        guard let backdropLayer else { return }

        var filters: [Any] = []

        // Telegram pipeline: color matrix first (vibrancy + saturation),
        // followed by gaussian blur.
        let matrixValues: [Float] = useTelegramMatrix
            ? Self.telegramColorMatrix
            : saturationMatrix(saturation)

        if let matrix = PrivateGlassAPI.makeColorMatrixValue(matrixValues),
           let colorMatrix = PrivateGlassAPI.makeFilter("colorMatrix") {
            colorMatrix.setValue(matrix, forKey: "inputColorMatrix")
            // Lets the filter scale with the backdrop instead of a snapshot.
            colorMatrix.setValue(true as NSNumber, forKey: "inputBackdropAware")
            filters.append(colorMatrix)
        }

        if blurRadius > 0, let blur = PrivateGlassAPI.makeFilter("gaussianBlur") {
            blur.setValue(blurRadius as NSNumber, forKey: "inputRadius")
            filters.append(blur)
        }

        PrivateGlassAPI.setFilters(filters, on: backdropLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let bounds = self.bounds
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous

        fallbackBlurView?.frame = bounds
        backdropLayer?.frame = bounds
        tintLayer.frame = bounds
        tintLayer.cornerRadius = cornerRadius
        tintLayer.cornerCurve = .continuous
        tintLayer.masksToBounds = true

        highlightLayer.frame = bounds
        highlightLayer.cornerRadius = cornerRadius
        highlightLayer.cornerCurve = .continuous
        highlightLayer.masksToBounds = true

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
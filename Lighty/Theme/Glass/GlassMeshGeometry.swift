import CoreGraphics
import Foundation

/// Builds the deformable mesh that gives a glass panel its lens-like edge.
///
/// The idea is simple: a quad grid covers the panel, and vertices close to the
/// rounded-rect edge are displaced inwards. Sampling the backdrop slightly
/// *inside* the panel at the border is what bends the image at the rim, while
/// the interior stays a plain, undistorted copy.
///
/// Everything here is pure geometry so it can be unit tested without a device.
struct GlassMeshGeometry {

    struct Parameters {
        /// Corner radius of the panel in points.
        var cornerRadius: CGFloat
        /// How far from the border the bend fades out, in points.
        var edgeBand: CGFloat
        /// Peak displacement of the outer border, in points.
        var displacement: CGFloat
        /// Number of cells along each axis. Higher is smoother and more
        /// expensive; 8x8 is invisible at panel sizes but cheap to build.
        var cellsPerAxis: Int
        /// Radial subdivisions inside the rounded corners.
        var cornerSteps: Int

        init(
            cornerRadius: CGFloat,
            edgeBand: CGFloat = 16,
            displacement: CGFloat = 14,
            cellsPerAxis: Int = 8,
            cornerSteps: Int = 4
        ) {
            self.cornerRadius = cornerRadius
            self.edgeBand = edgeBand
            self.displacement = displacement
            self.cellsPerAxis = max(1, cellsPerAxis)
            self.cornerSteps = max(1, cornerSteps)
        }
    }

    struct Mesh {
        var vertices: [GlassMeshVertex]
        var faces: [GlassMeshFace]
    }

    /// Signed distance from `point` to the boundary of a rounded rectangle:
    /// negative inside, zero on the border, positive outside.
    static func signedDistance(
        point: CGPoint,
        size: CGSize,
        cornerRadius: CGFloat
    ) -> CGFloat {
        let radius = max(0, min(cornerRadius, min(size.width, size.height) / 2))
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let centreX = point.x - halfWidth
        let centreY = point.y - halfHeight

        let outerX = abs(centreX) - (halfWidth - radius)
        let outerY = abs(centreY) - (halfHeight - radius)
        let outside = hypot(max(outerX, 0), max(outerY, 0))
        let inside = min(max(outerX, outerY), 0)
        return outside + inside - radius
    }

    /// Unit-space mesh for a panel of `size` points.
    ///
    /// `from` is in 0...1 of the layer, `to` is in 0...1 of the layer as well;
    /// Core Animation interprets both relative to the layer bounds and then
    /// scales by the layer size.
    static func makeMesh(size: CGSize, parameters: Parameters) -> Mesh {
        let width = max(1, size.width)
        let height = max(1, size.height)
        let radius = max(0, min(parameters.cornerRadius, min(width, height) / 2))
        let band = max(0.5, parameters.edgeBand)
        let magnitude = max(0, parameters.displacement)

        let cells = parameters.cellsPerAxis
        let gridWidth = CGFloat(cells)
        let gridHeight = CGFloat(cells)

        var vertices: [GlassMeshVertex] = []
        vertices.reserveCapacity((cells + 1) * (cells + 1))

        for row in 0...cells {
            for column in 0...cells {
                let u = CGFloat(column) / gridWidth
                let v = CGFloat(row) / gridHeight
                let point = CGPoint(x: u * width, y: v * height)

                let distance = signedDistance(point: point, size: CGSize(width: width, height: height), cornerRadius: radius)
                let offset = displacementVector(
                    at: point,
                    size: CGSize(width: width, height: height),
                    cornerRadius: radius,
                    distance: distance,
                    band: band,
                    magnitude: magnitude
                )

                // Displacing the *source* sample position is what bends the
                // image: the destination stays on the regular grid.
                let sourceX = clamp01(u + offset.x / width)
                let sourceY = clamp01(v + offset.y / height)
                vertices.append(GlassMeshVertex(
                    from: CGPoint(x: sourceX, y: sourceY),
                    to: GlassMeshPoint3D(x: u, y: v, z: 0)
                ))
            }
        }

        var faces: [GlassMeshFace] = []
        faces.reserveCapacity(cells * cells)

        for row in 0..<cells {
            for column in 0..<cells {
                let topLeft = UInt32(row * (cells + 1) + column)
                let topRight = topLeft + 1
                let bottomLeft = UInt32((row + 1) * (cells + 1) + column)
                let bottomRight = bottomLeft + 1
                faces.append(GlassMeshFace(
                    indices: (topLeft, topRight, bottomRight, bottomLeft),
                    weights: (0, 0, 0, 0)
                ))
            }
        }

        return Mesh(vertices: vertices, faces: faces)
    }

    /// Displacement in points. The dominant term is towards the panel centre,
    /// weighted by a smooth falloff so only the band next to the rim bends.
    private static func displacementVector(
        at point: CGPoint,
        size: CGSize,
        cornerRadius: CGFloat,
        distance: CGFloat,
        band: CGFloat,
        magnitude: CGFloat
    ) -> CGPoint {
        guard magnitude > 0 else { return .zero }

        // 0 at the outer edge of the band, 1 exactly on the border, and
        // clamped to 0 deeper inside.
        let proximity = max(0, min(1, (-distance) / band))
        guard proximity > 0 else { return .zero }

        // Smoothstep so the transition has no visible seam.
        let weight = proximity * proximity * (3 - 2 * proximity)
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let toCentre = CGVector(dx: centre.x - point.x, dy: centre.y - point.y)
        let length = hypot(toCentre.dx, toCentre.dy)
        guard length > 0.0001 else { return .zero }

        let scale = magnitude * weight / length
        return CGPoint(x: toCentre.dx * scale, y: toCentre.dy * scale)
    }

    private static func clamp01(_ value: CGFloat) -> CGFloat {
        max(0, min(1, value))
    }
}
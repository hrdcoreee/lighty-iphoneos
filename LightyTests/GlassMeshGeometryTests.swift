import XCTest
@testable import Lighty

/// The mesh is pure geometry, so its invariants can be checked without a
/// device. A wrong sign here would bend the glass outwards instead of inwards,
/// which is exactly the kind of bug a screenshot cannot disambiguate.
final class GlassMeshGeometryTests: XCTestCase {

    private let size = CGSize(width: 320, height: 200)

    private func parameters(_ configure: (inout GlassMeshGeometry.Parameters) -> Void = { _ in })
        -> GlassMeshGeometry.Parameters
    {
        var parameters = GlassMeshGeometry.Parameters(cornerRadius: 22)
        configure(&parameters)
        return parameters
    }

    func testSignedDistanceInsideTheStraightEdge() {
        // 10 pt inside the left edge of the panel.
        let distance = GlassMeshGeometry.signedDistance(
            point: CGPoint(x: 10, y: 100),
            size: size,
            cornerRadius: 22
        )
        XCTAssertEqual(distance, -10, accuracy: 0.001)
    }

    func testSignedDistanceOutsideThePanel() {
        let distance = GlassMeshGeometry.signedDistance(
            point: CGPoint(x: -6, y: 100),
            size: size,
            cornerRadius: 22
        )
        XCTAssertEqual(distance, 6, accuracy: 0.001)
    }

    func testSignedDistanceCornerIsRound() {
        // The corner centre is at (22, 22); this point is 22 pt diagonally
        // outwards from it, i.e. exactly on the arc.
        let point = CGPoint(
            x: 22 - 22 / 2.0.squareRoot(),
            y: 22 - 22 / 2.0.squareRoot()
        )
        let distance = GlassMeshGeometry.signedDistance(point: point, size: size, cornerRadius: 22)
        XCTAssertEqual(distance, 0, accuracy: 0.01)
    }

    func testMeshCoversTheGrid() {
        let mesh = GlassMeshGeometry.makeMesh(size: size, parameters: parameters())
        XCTAssertEqual(mesh.vertices.count, 81)
        XCTAssertEqual(mesh.faces.count, 64)
    }

    /// The destination of every vertex stays on the undistorted grid, so the
    /// panel keeps its shape and only the sampled image moves.
    func testDestinationsStayOnTheRegularGrid() {
        let mesh = GlassMeshGeometry.makeMesh(size: size, parameters: parameters())
        for vertex in mesh.vertices {
            XCTAssertGreaterThanOrEqual(vertex.to.x, 0)
            XCTAssertLessThanOrEqual(vertex.to.x, 1)
            XCTAssertGreaterThanOrEqual(vertex.to.y, 0)
            XCTAssertLessThanOrEqual(vertex.to.y, 1)
            XCTAssertEqual(vertex.to.z, 0)
        }
    }

    /// A point on the border must sample from *inside* the panel, otherwise the
    /// edge would smear content from outside the layer.
    func testBorderSamplesInwards() {
        let mesh = GlassMeshGeometry.makeMesh(
            size: size,
            parameters: parameters { $0.displacement = 14 }
        )

        // Leftmost column, middle row: pressed towards the centre.
        let leftEdge = mesh.vertices[4 * 9]
        XCTAssertGreaterThan(leftEdge.from.x, leftEdge.to.x)
        XCTAssertEqual(leftEdge.from.y, leftEdge.to.y, accuracy: 0.0001)

        // Top row, middle column: pressed downwards.
        let topEdge = mesh.vertices[4]
        XCTAssertGreaterThan(topEdge.from.y, topEdge.to.y)
        XCTAssertEqual(topEdge.from.x, topEdge.to.x, accuracy: 0.0001)
    }

    func testCentreIsUndisturbed() {
        let mesh = GlassMeshGeometry.makeMesh(size: size, parameters: parameters())
        // Grid has 9 points per axis; index 4,4 is the exact centre.
        let centre = mesh.vertices[4 * 9 + 4]
        XCTAssertEqual(centre.from.x, centre.to.x, accuracy: 0.0001)
        XCTAssertEqual(centre.from.y, centre.to.y, accuracy: 0.0001)
    }

    func testZeroDisplacementIsAPassThrough() {
        let mesh = GlassMeshGeometry.makeMesh(
            size: size,
            parameters: parameters { $0.displacement = 0 }
        )
        for vertex in mesh.vertices {
            XCTAssertEqual(vertex.from.x, vertex.to.x, accuracy: 0.0001)
            XCTAssertEqual(vertex.from.y, vertex.to.y, accuracy: 0.0001)
        }
    }

    /// Source coordinates must stay inside 0...1 or Core Animation clamps the
    /// sample and the rim picks up an edge-colour stripe.
    func testSourceCoordinatesStayClamped() {
        let mesh = GlassMeshGeometry.makeMesh(
            size: size,
            parameters: parameters {
                $0.displacement = 400
                $0.edgeBand = 2
            }
        )
        for vertex in mesh.vertices {
            XCTAssertGreaterThanOrEqual(vertex.from.x, 0)
            XCTAssertLessThanOrEqual(vertex.from.x, 1)
            XCTAssertGreaterThanOrEqual(vertex.from.y, 0)
            XCTAssertLessThanOrEqual(vertex.from.y, 1)
        }
    }

    func testDegenerateSizesDoNotProduceNaNs() {
        let mesh = GlassMeshGeometry.makeMesh(
            size: .zero,
            parameters: parameters()
        )
        for vertex in mesh.vertices {
            XCTAssertFalse(vertex.from.x.isNaN)
            XCTAssertFalse(vertex.from.y.isNaN)
            XCTAssertFalse(vertex.to.x.isNaN)
            XCTAssertFalse(vertex.to.y.isNaN)
        }
    }

    func testFaceIndicesStayInBounds() {
        let mesh = GlassMeshGeometry.makeMesh(size: size, parameters: parameters())
        let vertexCount = UInt32(mesh.vertices.count)
        for face in mesh.faces {
            for index in [face.indices.0, face.indices.1, face.indices.2, face.indices.3] {
                XCTAssertLessThan(index, vertexCount)
            }
        }
    }
}
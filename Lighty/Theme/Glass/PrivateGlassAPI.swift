import CoreGraphics
import QuartzCore
import UIKit

/// A mesh vertex for the private Core Animation mesh format.
///
/// This mirrors `LightyMeshVertex` from `GlassMeshShim.h`; the Objective-C shim
/// owns the actual ABI because `@convention(c)` cannot express these structs.
typealias GlassMeshVertex = LightyMeshVertex
typealias GlassMeshPoint3D = LightyMeshPoint3D
typealias GlassMeshFace = LightyMeshFace

/// Soft-linked access to the private Core Animation pieces that make a backdrop
/// layer refract what is behind it.
///
/// Nothing here is linked at build time: classes and selectors are resolved by
/// name, so an unavailable symbol degrades to `nil` instead of preventing the
/// app from launching. This is private API and only acceptable because the
/// build is sideloaded rather than submitted to the App Store.
enum PrivateGlassAPI {

    static var isBackdropAvailable: Bool { LightyGlassBackdropAvailable() }

    static var isMeshAvailable: Bool { LightyGlassMeshAvailable() }

    static var isFilterAvailable: Bool { LightyGlassFilterAvailable() }

    /// Creates a standalone backdrop layer at the given screen scale.
    static func makeBackdropLayer(scale: CGFloat) -> CALayer? {
        LightyGlassCreateBackdropLayer(scale)
    }

    /// Builds a `CAMeshTransform`. The shim calls the factory through
    /// `NSInvocation`, which avoids a hand-written C cast for the struct
    /// arguments.
    static func makeMesh(vertices: [GlassMeshVertex], faces: [GlassMeshFace]) -> AnyObject? {
        guard !vertices.isEmpty, !faces.isEmpty else { return nil }

        var vertexStorage = vertices
        var faceStorage = faces

        return vertexStorage.withUnsafeMutableBufferPointer { vertexBuffer in
            faceStorage.withUnsafeMutableBufferPointer { faceBuffer in
                guard let vertexPointer = vertexBuffer.baseAddress,
                      let facePointer = faceBuffer.baseAddress else {
                    return nil
                }
                return LightyGlassMakeMesh(
                    UInt(vertexBuffer.count),
                    vertexPointer,
                    UInt(faceBuffer.count),
                    facePointer
                )
            }
        } as AnyObject?
    }

    static func canApplyMesh(to layer: CALayer) -> Bool {
        LightyGlassCanApplyMesh(layer)
    }

    @discardableResult
    static func applyMesh(_ mesh: AnyObject?, to layer: CALayer) -> Bool {
        guard let mesh else { return false }
        return LightyGlassApplyMesh(layer, mesh)
    }

    static func makeFilter(_ name: String) -> NSObject? {
        LightyGlassMakeFilter(name)
    }

    /// `CAColorMatrix` is a 20-float struct passed to `CAFilter` as an
    /// `NSValue` with an explicit Objective-C type encoding.
    static func makeColorMatrixValue(_ values: [Float]) -> NSValue? {
        guard values.count == 20 else { return nil }
        var storage = values
        return storage.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return nil }
            return LightyGlassColorMatrixValue(base)
        }
    }

    static func setFilters(_ filters: [Any], on layer: CALayer) {
        LightyGlassSetFilters(layer, filters as NSArray)
    }
}
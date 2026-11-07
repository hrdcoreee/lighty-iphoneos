import CoreGraphics
import Foundation
import ObjectiveC
import QuartzCore
import UIKit

/// A mesh vertex in Core Animation's private mesh format.
///
/// `from` is the source sample position in the layer's unit space, `to` is the
/// destination position (unit space or points, depending on the caller).
struct GlassMeshVertex {
    var from: CGPoint
    var to: GlassMeshPoint3D
}

struct GlassMeshPoint3D {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
}

struct GlassMeshFace {
    var indices: (UInt32, UInt32, UInt32, UInt32)
    var weights: (Float, Float, Float, Float)
}

/// Soft-linked access to the private Core Animation pieces that make a
/// backdrop layer refract what is behind it.
///
/// Nothing here is linked at build time: classes and selectors are resolved by
/// name, so an unavailable symbol degrades to `nil` instead of preventing the
/// app from launching. This is the same technique several shipping apps use;
/// it is private API and only safe because this build is sideloaded, not
/// submitted to the App Store.
enum PrivateGlassAPI {

    static let meshFactorySelector = NSSelectorFromString(
        "meshTransformWithVertexCount:vertices:faceCount:faces:depthNormalization:"
    )

    static let setMeshSelector = NSSelectorFromString("setMeshTransform:")

    static let backdropLayerType: CALayer.Type? = {
        guard let type = NSClassFromString("CABackdropLayer") else { return nil }
        return type as? CALayer.Type
    }()

    static let meshTransformType: AnyClass? = NSClassFromString("CAMutableMeshTransform")

    static let filterType: AnyClass? = NSClassFromString("CAFilter")

    static var isBackdropAvailable: Bool { backdropLayerType != nil }

    static var isMeshAvailable: Bool {
        guard let type = meshTransformType else { return false }
        return class_getClassMethod(type, meshFactorySelector) != nil
    }

    static var isFilterAvailable: Bool {
        guard let type = filterType else { return false }
        return class_getClassMethod(type, NSSelectorFromString("filterWithName:")) != nil
    }

    /// Creates a standalone backdrop layer. `alloc`/`init` are called through
    /// their IMPs because the dynamic class cannot be statically instantiated.
    static func makeBackdropLayer(scale: CGFloat) -> CALayer? {
        guard let type = backdropLayerType else { return nil }
        guard let allocMethod = class_getClassMethod(type, NSSelectorFromString("alloc")),
              let initMethod = class_getInstanceMethod(type, NSSelectorFromString("init")) else {
            return nil
        }

        typealias AllocFn = @convention(c) (AnyObject, Selector) -> AnyObject?
        typealias InitFn = @convention(c) (AnyObject, Selector) -> AnyObject?

        let allocFn = unsafeBitCast(method_getImplementation(allocMethod), to: AllocFn.self)
        guard let allocated = allocFn(type, NSSelectorFromString("alloc")) else { return nil }

        let initFn = unsafeBitCast(method_getImplementation(initMethod), to: InitFn.self)
        guard let instance = initFn(allocated, NSSelectorFromString("init")) else { return nil }
        guard let layer = instance as? CALayer else { return nil }

        // A backdrop layer that does not know its scale samples nothing.
        if let scaleMethod = class_getInstanceMethod(type, NSSelectorFromString("setScale:")) {
            typealias SetScaleFn = @convention(c) (AnyObject, Selector, Double) -> Void
            let setScale = unsafeBitCast(method_getImplementation(scaleMethod), to: SetScaleFn.self)
            setScale(layer, NSSelectorFromString("setScale:"), Double(scale))
        }
        layer.rasterizationScale = scale
        return layer
    }

    /// Builds a `CAMeshTransform` from vertices and quad faces.
    static func makeMesh(vertices: [GlassMeshVertex], faces: [GlassMeshFace]) -> AnyObject? {
        guard let type = meshTransformType,
              let method = class_getClassMethod(type, meshFactorySelector),
              !vertices.isEmpty, !faces.isEmpty else {
            return nil
        }

        typealias FactoryFn = @convention(c) (
            AnyObject,
            Selector,
            UInt,
            UnsafeMutablePointer<GlassMeshVertex>,
            UInt,
            UnsafeMutablePointer<GlassMeshFace>,
            NSString
        ) -> AnyObject?

        var vertexStorage = vertices
        var faceStorage = faces
        let factory = unsafeBitCast(method_getImplementation(method), to: FactoryFn.self)

        let result: AnyObject? = vertexStorage.withUnsafeMutableBufferPointer { vertexBuffer in
            faceStorage.withUnsafeMutableBufferPointer { faceBuffer in
                guard let vertexPointer = vertexBuffer.baseAddress,
                      let facePointer = faceBuffer.baseAddress else {
                    return nil
                }
                return factory(
                    type,
                    meshFactorySelector,
                    UInt(vertexBuffer.count),
                    vertexPointer,
                    UInt(faceBuffer.count),
                    facePointer,
                    "none" as NSString
                )
            }
        }

        if let result,
           let stepsMethod = class_getInstanceMethod(type, NSSelectorFromString("setSubdivisionSteps:")) {
            typealias SetStepsFn = @convention(c) (AnyObject, Selector, Int) -> Void
            let setSteps = unsafeBitCast(method_getImplementation(stepsMethod), to: SetStepsFn.self)
            setSteps(result, NSSelectorFromString("setSubdivisionSteps:"), 0)
        }

        return result
    }

    /// Attaches a mesh to a layer. Returns false when the layer does not
    /// implement `setMeshTransform:` (older or newer iOS, or a layer type that
    /// ignores it).
    @discardableResult
    static func applyMesh(_ mesh: AnyObject?, to layer: CALayer) -> Bool {
        guard let type = object_getClass(layer),
              let method = class_getInstanceMethod(type, setMeshSelector) else {
            return false
        }
        typealias SetMeshFn = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let setMesh = unsafeBitCast(method_getImplementation(method), to: SetMeshFn.self)
        setMesh(layer, setMeshSelector, mesh)
        return true
    }

    static func canApplyMesh(to layer: CALayer) -> Bool {
        guard let type = object_getClass(layer) else { return false }
        return class_getInstanceMethod(type, setMeshSelector) != nil
    }

    /// Creates a `CAFilter` by name, for example `gaussianBlur` or
    /// `colorMatrix`.
    static func makeFilter(_ name: String) -> NSObject? {
        guard let type = filterType,
              let method = class_getClassMethod(type, NSSelectorFromString("filterWithName:")) else {
            return nil
        }
        typealias FactoryFn = @convention(c) (AnyObject, Selector, NSString) -> AnyObject?
        let factory = unsafeBitCast(method_getImplementation(method), to: FactoryFn.self)
        return factory(type, NSSelectorFromString("filterWithName:"), name as NSString) as? NSObject
    }

    /// `CAColorMatrix` is a 20-float struct; it is passed to `CAFilter` as an
    /// `NSValue` with an explicit Objective-C type encoding.
    static func makeColorMatrixValue(_ values: [Float]) -> NSValue? {
        guard values.count == 20 else { return nil }
        var storage = values
        return NSValue(bytes: &storage, objCType: "{CAColorMatrix=ffffffffffffffffffff}")
    }
}
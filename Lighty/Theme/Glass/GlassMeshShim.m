#import "GlassMeshShim.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

static Class LightyGlassClass(NSString *name) {
    return NSClassFromString(name);
}

BOOL LightyGlassBackdropAvailable(void) {
    return LightyGlassClass(@"CABackdropLayer") != Nil;
}

BOOL LightyGlassMeshAvailable(void) {
    Class cls = LightyGlassClass(@"CAMutableMeshTransform");
    if (cls == Nil) {
        return NO;
    }
    return [cls respondsToSelector:NSSelectorFromString(@"meshTransformWithVertexCount:vertices:faceCount:faces:depthNormalization:")];
}

BOOL LightyGlassFilterAvailable(void) {
    Class cls = LightyGlassClass(@"CAFilter");
    if (cls == Nil) {
        return NO;
    }
    return [cls respondsToSelector:NSSelectorFromString(@"filterWithName:")];
}

CALayer *LightyGlassCreateBackdropLayer(CGFloat scale) {
    Class cls = LightyGlassClass(@"CABackdropLayer");
    if (cls == Nil) {
        return nil;
    }

    id allocated = ((id (*)(id, SEL))objc_msgSend)((id)cls, sel_registerName("alloc"));
    if (allocated == nil) {
        return nil;
    }
    id instance = ((id (*)(id, SEL))objc_msgSend)(allocated, sel_registerName("init"));
    if (instance == nil) {
        return nil;
    }
    if (![instance isKindOfClass:[CALayer class]]) {
        return nil;
    }

    SEL setScaleSelector = NSSelectorFromString(@"setScale:");
    if ([instance respondsToSelector:setScaleSelector]) {
        ((void (*)(id, SEL, double))objc_msgSend)(instance, setScaleSelector, (double)scale);
    }
    ((CALayer *)instance).rasterizationScale = scale;
    return (CALayer *)instance;
}

/// The factory takes four struct arguments, so the call is assembled with
/// `NSInvocation` rather than a hand-written function cast.
static id LightyGlassInvokeMeshFactory(Class cls,
                                       NSUInteger vertexCount,
                                       const LightyMeshVertex *vertices,
                                       NSUInteger faceCount,
                                       const LightyMeshFace *faces) {
    SEL selector = NSSelectorFromString(@"meshTransformWithVertexCount:vertices:faceCount:faces:depthNormalization:");
    if (![cls respondsToSelector:selector]) {
        return nil;
    }

    NSMethodSignature *signature = [cls methodSignatureForSelector:selector];
    if (signature == nil) {
        return nil;
    }

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setTarget:(id)cls];

    NSUInteger count = vertexCount;
    NSUInteger facesTotal = faceCount;
    const LightyMeshVertex *vertexPointer = vertices;
    const LightyMeshFace *facePointer = faces;
    NSString *normalization = @"none";

    [invocation setArgument:&count atIndex:2];
    [invocation setArgument:&vertexPointer atIndex:3];
    [invocation setArgument:&facesTotal atIndex:4];
    [invocation setArgument:&facePointer atIndex:5];
    [invocation setArgument:&normalization atIndex:6];
    [invocation invoke];

    __unsafe_unretained id result = nil;
    [invocation getReturnValue:&result];
    return result;
}

id LightyGlassMakeMesh(NSUInteger vertexCount,
                       const LightyMeshVertex *vertices,
                       NSUInteger faceCount,
                       const LightyMeshFace *faces) {
    if (vertices == NULL || faces == NULL || vertexCount == 0 || faceCount == 0) {
        return nil;
    }

    Class cls = LightyGlassClass(@"CAMutableMeshTransform");
    if (cls == Nil) {
        return nil;
    }

    id mesh = LightyGlassInvokeMeshFactory(cls, vertexCount, vertices, faceCount, faces);
    if (mesh == nil) {
        return nil;
    }

    SEL stepsSelector = NSSelectorFromString(@"setSubdivisionSteps:");
    if ([mesh respondsToSelector:stepsSelector]) {
        ((void (*)(id, SEL, long))objc_msgSend)(mesh, stepsSelector, (long)0);
    }
    return mesh;
}

BOOL LightyGlassCanApplyMesh(CALayer *layer) {
    return [layer respondsToSelector:NSSelectorFromString(@"setMeshTransform:")];
}

BOOL LightyGlassApplyMesh(CALayer *layer, id mesh) {
    SEL selector = NSSelectorFromString(@"setMeshTransform:");
    if (![layer respondsToSelector:selector]) {
        return NO;
    }
    ((void (*)(id, SEL, id))objc_msgSend)(layer, selector, mesh);
    return YES;
}

NSObject *LightyGlassMakeFilter(NSString *name) {
    Class cls = LightyGlassClass(@"CAFilter");
    SEL selector = NSSelectorFromString(@"filterWithName:");
    if (cls == Nil || ![cls respondsToSelector:selector]) {
        return nil;
    }
    id filter = ((id (*)(id, SEL, NSString *))objc_msgSend)((id)cls, selector, name);
    return [filter isKindOfClass:[NSObject class]] ? (NSObject *)filter : nil;
}

NSValue *LightyGlassColorMatrixValue(const float *values) {
    if (values == NULL) {
        return nil;
    }
    return [NSValue valueWithBytes:values objCType:"{CAColorMatrix=ffffffffffffffffffff}"];
}

void LightyGlassSetFilters(CALayer *layer, NSArray *filters) {
    [layer setValue:filters forKey:@"filters"];
}
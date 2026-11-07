#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A point in the private Core Animation mesh format.
typedef struct {
    CGFloat x;
    CGFloat y;
    CGFloat z;
} LightyMeshPoint3D;

/// One mesh vertex: where to sample (`from`) and where to draw (`to`).
///
/// Both positions are in the layer's unit space (0...1).
typedef struct {
    CGPoint from;
    LightyMeshPoint3D to;
} LightyMeshVertex;

/// A quad face referencing four vertices and their bilinear weights.
typedef struct {
    uint32_t indices[4];
    float weights[4];
} LightyMeshFace;

BOOL LightyGlassBackdropAvailable(void);
BOOL LightyGlassMeshAvailable(void);
BOOL LightyGlassFilterAvailable(void);

nullable CALayer *LightyGlassCreateBackdropLayer(CGFloat scale);

nullable id LightyGlassMakeMesh(NSUInteger vertexCount,
                                const LightyMeshVertex *vertices,
                                NSUInteger faceCount,
                                const LightyMeshFace *faces);

BOOL LightyGlassCanApplyMesh(CALayer *layer);
BOOL LightyGlassApplyMesh(CALayer *layer, id mesh);

nullable NSObject *LightyGlassMakeFilter(NSString *name);

nullable NSValue *LightyGlassColorMatrixValue(const float *values);

void LightyGlassSetFilters(CALayer *layer, NSArray *filters);

NS_ASSUME_NONNULL_END
#import "FaceAnalysisFrame.h"

@implementation FaceAnalysisFrame

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                        observations:(NSArray<FaceRiskObservation *> *)observations
                           timestamp:(NSTimeInterval)timestamp {
    self = [super init];
    if (self) {
        _pixelBuffer = CVPixelBufferRetain(pixelBuffer);
        _observations = [observations copy];
        _timestamp = timestamp;
    }
    return self;
}

- (void)dealloc {
    if (_pixelBuffer) CVPixelBufferRelease(_pixelBuffer);
}

@end

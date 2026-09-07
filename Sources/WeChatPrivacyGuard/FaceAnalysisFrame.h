#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import "FaceRiskEvaluator.h"

NS_ASSUME_NONNULL_BEGIN

@interface FaceAnalysisFrame : NSObject

@property(nonatomic, readonly) CVPixelBufferRef pixelBuffer;
@property(nonatomic, copy, readonly) NSArray<FaceRiskObservation *> *observations;
@property(nonatomic, readonly) NSTimeInterval timestamp;

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                        observations:(NSArray<FaceRiskObservation *> *)observations
                           timestamp:(NSTimeInterval)timestamp;

@end

NS_ASSUME_NONNULL_END

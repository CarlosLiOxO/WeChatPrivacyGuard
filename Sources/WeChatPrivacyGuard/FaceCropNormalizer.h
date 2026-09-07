#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const FaceCropNormalizerErrorDomain;

@interface FaceCropNormalizer : NSObject

- (nullable CVPixelBufferRef)createNormalizedFacePixelBufferFromSource:(CVPixelBufferRef)source
                                                            boundingBox:(CGRect)boundingBox
                                                                  error:(NSError **)error CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END

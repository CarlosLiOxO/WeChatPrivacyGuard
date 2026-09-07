#import <CoreML/CoreML.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const FaceEmbeddingProviderErrorDomain;

@interface FaceEmbeddingProvider : NSObject

@property(nonatomic, readonly) NSUInteger embeddingDimension;

- (nullable instancetype)initWithModelURL:(NSURL *)modelURL error:(NSError **)error;
- (nullable NSArray<NSNumber *> *)embeddingForPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                                     error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

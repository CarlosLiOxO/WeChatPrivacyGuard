#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "OwnerFaceMatcher.h"

NS_ASSUME_NONNULL_BEGIN

@interface FaceIdentityCache : NSObject

@property(nonatomic, readonly) NSUInteger count;

- (instancetype)initWithTimeToLive:(NSTimeInterval)timeToLive
                 minimumOverlapRatio:(CGFloat)minimumOverlapRatio;
- (void)storeIdentity:(FaceIdentityResult)identity
          boundingBox:(CGRect)boundingBox
               atTime:(NSTimeInterval)time;
- (nullable NSNumber *)cachedIdentityForBoundingBox:(CGRect)boundingBox
                                             atTime:(NSTimeInterval)time;
- (void)removeExpiredEntriesAtTime:(NSTimeInterval)time;
- (void)reset;

@end

NS_ASSUME_NONNULL_END

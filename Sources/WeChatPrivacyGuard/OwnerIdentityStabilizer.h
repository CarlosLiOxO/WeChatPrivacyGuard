#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "OwnerFaceMatcher.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT BOOL OwnerIdentityBoundingBoxesBelongToSameTrack(CGRect previousBox,
                                                                   CGRect currentBox);

@interface OwnerIdentityStabilizer : NSObject

- (instancetype)initWithRequiredUnknownObservations:(NSUInteger)requiredUnknownObservations
                              minimumUnknownDuration:(NSTimeInterval)minimumUnknownDuration
                               maximumObservationGap:(NSTimeInterval)maximumObservationGap
                                maximumOwnerTrackGap:(NSTimeInterval)maximumOwnerTrackGap;
- (FaceIdentityResult)stabilizedIdentityForRawIdentity:(FaceIdentityResult)rawIdentity
                                           boundingBox:(CGRect)boundingBox
                                                atTime:(NSTimeInterval)time;
- (void)reset;

@end

NS_ASSUME_NONNULL_END

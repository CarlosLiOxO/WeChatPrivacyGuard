#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "OwnerFaceMatcher.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT CGFloat MinimumFaceCaptureQualityForOwnerMatching(void);
FOUNDATION_EXPORT CGFloat MinimumFaceCaptureQualityForUnknownDecision(void);
FOUNDATION_EXPORT BOOL FaceCaptureQualitySupportsOwnerMatching(NSNumber * _Nullable captureQuality);
FOUNDATION_EXPORT BOOL FaceCaptureQualitySupportsUnknownDecision(NSNumber * _Nullable captureQuality);
FOUNDATION_EXPORT FaceIdentityResult FaceIdentityResultRespectingCaptureQuality(
    FaceIdentityResult rawIdentity, NSNumber * _Nullable captureQuality);

NS_ASSUME_NONNULL_END

#import "FaceIdentityQuality.h"
#import <math.h>

// Apple Vision's capture-quality score is camera and lighting dependent. The
// development camera measured 0.326-0.390 for an unobstructed owner, while the
// reported hand-occlusion sample measured 0.336. A single threshold therefore
// cannot both recognize the owner and reject distorted stranger evidence.
static const CGFloat MinimumOwnerMatchingCaptureQuality = 0.30;
static const CGFloat MinimumUnknownDecisionCaptureQuality = 0.40;

CGFloat MinimumFaceCaptureQualityForOwnerMatching(void) {
    return MinimumOwnerMatchingCaptureQuality;
}

CGFloat MinimumFaceCaptureQualityForUnknownDecision(void) {
    return MinimumUnknownDecisionCaptureQuality;
}

static BOOL FaceCaptureQualityMeetsThreshold(NSNumber *captureQuality, CGFloat threshold) {
    if (!captureQuality) return NO;
    double value = captureQuality.doubleValue;
    return isfinite(value) && value >= threshold && value <= 1.0;
}

BOOL FaceCaptureQualitySupportsOwnerMatching(NSNumber *captureQuality) {
    return FaceCaptureQualityMeetsThreshold(captureQuality,
                                            MinimumOwnerMatchingCaptureQuality);
}

BOOL FaceCaptureQualitySupportsUnknownDecision(NSNumber *captureQuality) {
    return FaceCaptureQualityMeetsThreshold(captureQuality,
                                            MinimumUnknownDecisionCaptureQuality);
}

FaceIdentityResult FaceIdentityResultRespectingCaptureQuality(
    FaceIdentityResult rawIdentity, NSNumber *captureQuality) {
    if (rawIdentity == FaceIdentityResultOwner) {
        return FaceCaptureQualitySupportsOwnerMatching(captureQuality)
            ? rawIdentity : FaceIdentityResultAmbiguous;
    }
    if (rawIdentity == FaceIdentityResultUnknown) {
        return FaceCaptureQualitySupportsUnknownDecision(captureQuality)
            ? rawIdentity : FaceIdentityResultAmbiguous;
    }
    return FaceIdentityResultAmbiguous;
}

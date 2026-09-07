#import "OwnerAwareRiskEvaluator.h"
#import <math.h>

static const CGFloat OwnerAwareMinimumEffectiveFaceArea = 0.001;
static const CGFloat OwnerAwareBorderlineRatio = 0.85;
static const CGFloat IdentityCropExpansion = 1.38;
static const CGFloat IdentityCropVerticalOffset = 0.03;
static const CGFloat IdentityCropEdgeTolerance = 0.01;
static const double MaximumScreenViewingYaw = 0.42;

BOOL FaceBoundingBoxSupportsReliableIdentityCrop(CGRect boundingBox) {
    CGFloat width = CGRectGetWidth(boundingBox);
    CGFloat height = CGRectGetHeight(boundingBox);
    if (!isfinite(width) || !isfinite(height) || width <= 0 || height <= 0) return NO;
    CGFloat side = MAX(width, height) * IdentityCropExpansion;
    CGPoint center = CGPointMake(CGRectGetMidX(boundingBox),
                                 CGRectGetMidY(boundingBox) + side * IdentityCropVerticalOffset);
    CGRect expandedCrop = CGRectMake(center.x - side / 2, center.y - side / 2, side, side);
    return CGRectGetMinX(expandedCrop) >= IdentityCropEdgeTolerance &&
        CGRectGetMinY(expandedCrop) >= IdentityCropEdgeTolerance &&
        CGRectGetMaxX(expandedCrop) <= 1 - IdentityCropEdgeTolerance &&
        CGRectGetMaxY(expandedCrop) <= 1 - IdentityCropEdgeTolerance;
}

BOOL FacePoseCanViewScreen(NSNumber *yaw) {
    return yaw && isfinite(yaw.doubleValue) && fabs(yaw.doubleValue) <= MaximumScreenViewingYaw;
}

BOOL OwnerAwareFaceCanTriggerPrivacy(CGRect boundingBox, NSNumber *yaw) {
    return FaceBoundingBoxSupportsReliableIdentityCrop(boundingBox) && FacePoseCanViewScreen(yaw);
}

@implementation OwnerAwareFaceObservation

- (instancetype)initWithBoundingBox:(CGRect)boundingBox
                                yaw:(NSNumber *)yaw
                     identityResult:(FaceIdentityResult)identityResult {
    self = [super init];
    if (self) {
        _boundingBox = boundingBox;
        _yaw = yaw;
        _identityResult = identityResult;
    }
    return self;
}

@end

@implementation OwnerAwareRiskEvaluator

- (instancetype)initWithProtectionDistance:(ProtectionDistance)protectionDistance {
    self = [super init];
    if (self) _protectionDistance = protectionDistance;
    return self;
}

- (FaceRiskState)evaluateObservations:(NSArray<OwnerAwareFaceObservation *> *)observations {
    CGFloat threshold = FaceHeightThresholdForProtectionDistance(self.protectionDistance);
    BOOL hasBorderlineCandidate = NO;
    NSUInteger eligibleFaceCount = 0;
    for (OwnerAwareFaceObservation *face in observations) {
        if (OwnerAwareFaceCanTriggerPrivacy(face.boundingBox, face.yaw)) eligibleFaceCount += 1;
    }
    for (OwnerAwareFaceObservation *face in observations) {
        if (face.identityResult == FaceIdentityResultOwner) continue;

        CGFloat width = CGRectGetWidth(face.boundingBox);
        CGFloat height = CGRectGetHeight(face.boundingBox);
        CGFloat area = width * height;
        if (!isfinite(width) || !isfinite(height) || area < OwnerAwareMinimumEffectiveFaceArea) continue;
        if (!OwnerAwareFaceCanTriggerPrivacy(face.boundingBox, face.yaw)) continue;

        // A single uncertain face is commonly the owner under lighting or pose variation.
        // With multiple eligible faces, ambiguity still falls back to second-person protection.
        if (face.identityResult == FaceIdentityResultAmbiguous && eligibleFaceCount == 1) continue;

        if (height >= threshold) return FaceRiskStatePresent;
        if (height >= threshold * OwnerAwareBorderlineRatio) hasBorderlineCandidate = YES;
    }
    return hasBorderlineCandidate ? FaceRiskStateBorderline : FaceRiskStateNone;
}

@end

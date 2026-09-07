#import "FaceRiskEvaluator.h"
#import <math.h>

static const CGFloat MinimumEffectiveFaceArea = 0.001;
static const CGFloat BorderlineRatio = 0.85;
static const double MaximumAcceptedYaw = M_PI_4;

CGFloat FaceHeightThresholdForProtectionDistance(ProtectionDistance distance) {
    switch (distance) {
        case ProtectionDistanceNear:
            return 0.18;
        case ProtectionDistanceFar:
            return 0.065;
        case ProtectionDistanceStandard:
        default:
            return 0.11;
    }
}

@implementation FaceRiskObservation

- (instancetype)initWithBoundingBox:(CGRect)boundingBox yaw:(NSNumber *)yaw {
    return [self initWithBoundingBox:boundingBox yaw:yaw captureQuality:nil];
}

- (instancetype)initWithBoundingBox:(CGRect)boundingBox
                                yaw:(NSNumber *)yaw
                     captureQuality:(NSNumber *)captureQuality {
    self = [super init];
    if (self) {
        _boundingBox = boundingBox;
        _yaw = yaw;
        _captureQuality = captureQuality;
    }
    return self;
}

@end

@implementation FaceRiskEvaluator

- (instancetype)initWithProtectionDistance:(ProtectionDistance)protectionDistance {
    self = [super init];
    if (self) {
        _protectionDistance = protectionDistance;
    }
    return self;
}

- (FaceRiskState)evaluateObservations:(NSArray<FaceRiskObservation *> *)observations {
    if (observations.count < 2) return FaceRiskStateNone;

    NSArray<FaceRiskObservation *> *sorted = [observations sortedArrayUsingComparator:^NSComparisonResult(
        FaceRiskObservation *left, FaceRiskObservation *right) {
        CGFloat leftArea = CGRectGetWidth(left.boundingBox) * CGRectGetHeight(left.boundingBox);
        CGFloat rightArea = CGRectGetWidth(right.boundingBox) * CGRectGetHeight(right.boundingBox);
        if (leftArea > rightArea) return NSOrderedAscending;
        if (leftArea < rightArea) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    CGFloat threshold = FaceHeightThresholdForProtectionDistance(self.protectionDistance);
    BOOL hasBorderlineCandidate = NO;
    for (NSUInteger index = 1; index < sorted.count; index++) {
        FaceRiskObservation *face = sorted[index];
        CGFloat width = CGRectGetWidth(face.boundingBox);
        CGFloat height = CGRectGetHeight(face.boundingBox);
        CGFloat area = width * height;
        if (area < MinimumEffectiveFaceArea) continue;

        if (face.yaw && fabs(face.yaw.doubleValue) > MaximumAcceptedYaw) continue;
        if (height >= threshold) return FaceRiskStatePresent;
        if (height >= threshold * BorderlineRatio) hasBorderlineCandidate = YES;
    }
    return hasBorderlineCandidate ? FaceRiskStateBorderline : FaceRiskStateNone;
}

@end

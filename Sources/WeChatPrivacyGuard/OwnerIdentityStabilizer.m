#import "OwnerIdentityStabilizer.h"
#import <math.h>

@interface OwnerIdentityStabilizer ()
@property(nonatomic) NSUInteger requiredUnknownObservations;
@property(nonatomic) NSTimeInterval minimumUnknownDuration;
@property(nonatomic) NSTimeInterval maximumObservationGap;
@property(nonatomic) NSTimeInterval maximumOwnerTrackGap;
@property(nonatomic) NSUInteger consecutiveUnknownObservations;
@property(nonatomic) NSTimeInterval firstUnknownTime;
@property(nonatomic) NSTimeInterval lastUnknownTime;
@property(nonatomic) CGRect lastOwnerBoundingBox;
@property(nonatomic) NSTimeInterval lastOwnerObservationTime;
@property(nonatomic) BOOL ownerTrackActive;
@end

static BOOL OwnerIdentityBoundingBoxIsValid(CGRect box) {
    return isfinite(CGRectGetMinX(box)) && isfinite(CGRectGetMinY(box)) &&
        isfinite(CGRectGetWidth(box)) && isfinite(CGRectGetHeight(box)) &&
        CGRectGetWidth(box) > 0 && CGRectGetHeight(box) > 0;
}

BOOL OwnerIdentityBoundingBoxesBelongToSameTrack(CGRect previousBox, CGRect currentBox) {
    if (!OwnerIdentityBoundingBoxIsValid(previousBox) ||
        !OwnerIdentityBoundingBoxIsValid(currentBox)) return NO;

    CGRect intersection = CGRectIntersection(previousBox, currentBox);
    CGFloat intersectionArea = CGRectIsNull(intersection) || CGRectIsEmpty(intersection)
        ? 0 : CGRectGetWidth(intersection) * CGRectGetHeight(intersection);
    CGFloat previousArea = CGRectGetWidth(previousBox) * CGRectGetHeight(previousBox);
    CGFloat currentArea = CGRectGetWidth(currentBox) * CGRectGetHeight(currentBox);
    CGFloat unionArea = previousArea + currentArea - intersectionArea;
    if (unionArea > 0 && intersectionArea / unionArea >= 0.12) return YES;

    CGFloat deltaX = CGRectGetMidX(previousBox) - CGRectGetMidX(currentBox);
    CGFloat deltaY = CGRectGetMidY(previousBox) - CGRectGetMidY(currentBox);
    CGFloat centerDistance = hypot(deltaX, deltaY);
    CGFloat referenceSize = MAX(MAX(CGRectGetWidth(previousBox), CGRectGetHeight(previousBox)),
                                MAX(CGRectGetWidth(currentBox), CGRectGetHeight(currentBox)));
    CGFloat areaRatio = MIN(previousArea, currentArea) / MAX(previousArea, currentArea);
    return areaRatio >= 0.35 && centerDistance <= referenceSize * 0.72;
}

@implementation OwnerIdentityStabilizer

- (instancetype)initWithRequiredUnknownObservations:(NSUInteger)requiredUnknownObservations
                              minimumUnknownDuration:(NSTimeInterval)minimumUnknownDuration
                               maximumObservationGap:(NSTimeInterval)maximumObservationGap
                                maximumOwnerTrackGap:(NSTimeInterval)maximumOwnerTrackGap {
    self = [super init];
    if (self) {
        _requiredUnknownObservations = MAX((NSUInteger)1, requiredUnknownObservations);
        _minimumUnknownDuration = MAX(0, minimumUnknownDuration);
        _maximumObservationGap = MAX(0, maximumObservationGap);
        _maximumOwnerTrackGap = MAX(0, maximumOwnerTrackGap);
    }
    return self;
}

- (FaceIdentityResult)stabilizedIdentityForRawIdentity:(FaceIdentityResult)rawIdentity
                                           boundingBox:(CGRect)boundingBox
                                                atTime:(NSTimeInterval)time {
    if (!isfinite(time) || !OwnerIdentityBoundingBoxIsValid(boundingBox)) {
        [self reset];
        return FaceIdentityResultAmbiguous;
    }
    if (rawIdentity == FaceIdentityResultOwner) {
        [self resetUnknownEvidence];
        self.lastOwnerBoundingBox = boundingBox;
        self.lastOwnerObservationTime = time;
        self.ownerTrackActive = YES;
        return FaceIdentityResultOwner;
    }

    BOOL continuesOwnerTrack = self.ownerTrackActive &&
        time >= self.lastOwnerObservationTime &&
        time - self.lastOwnerObservationTime <= self.maximumOwnerTrackGap &&
        OwnerIdentityBoundingBoxesBelongToSameTrack(self.lastOwnerBoundingBox, boundingBox);
    if (continuesOwnerTrack) {
        [self resetUnknownEvidence];
        self.lastOwnerBoundingBox = boundingBox;
        self.lastOwnerObservationTime = time;
        return FaceIdentityResultOwner;
    }
    self.ownerTrackActive = NO;

    if (rawIdentity == FaceIdentityResultAmbiguous) {
        [self resetUnknownEvidence];
        return rawIdentity;
    }

    BOOL startsNewSequence = self.consecutiveUnknownObservations == 0 ||
        time < self.lastUnknownTime || time - self.lastUnknownTime > self.maximumObservationGap;
    if (startsNewSequence) {
        self.consecutiveUnknownObservations = 1;
        self.firstUnknownTime = time;
    } else {
        self.consecutiveUnknownObservations += 1;
    }
    self.lastUnknownTime = time;

    BOOL hasEnoughObservations = self.consecutiveUnknownObservations >= self.requiredUnknownObservations;
    BOOL hasEnoughDuration = time - self.firstUnknownTime >= self.minimumUnknownDuration;
    return hasEnoughObservations && hasEnoughDuration
        ? FaceIdentityResultUnknown : FaceIdentityResultAmbiguous;
}

- (void)reset {
    [self resetUnknownEvidence];
    self.lastOwnerBoundingBox = CGRectZero;
    self.lastOwnerObservationTime = 0;
    self.ownerTrackActive = NO;
}

- (void)resetUnknownEvidence {
    self.consecutiveUnknownObservations = 0;
    self.firstUnknownTime = 0;
    self.lastUnknownTime = 0;
}

@end

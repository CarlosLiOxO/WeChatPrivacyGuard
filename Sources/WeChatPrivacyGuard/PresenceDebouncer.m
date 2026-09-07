#import "PresenceDebouncer.h"

@interface PresenceDebouncer ()
@property(nonatomic) NSTimeInterval requiredDuration;
@property(nonatomic) NSTimeInterval firstRiskTime;
@property(nonatomic) BOOL hasFirstRiskTime;
@property(nonatomic) BOOL didTriggerForCurrentPresence;
@property(nonatomic) NSInteger consecutiveBorderlineFrames;
@end

@implementation PresenceDebouncer

- (instancetype)initWithRequiredDuration:(NSTimeInterval)requiredDuration {
    self = [super init];
    if (self) {
        _requiredDuration = requiredDuration;
    }
    return self;
}

- (BOOL)recordRiskState:(FaceRiskState)riskState atTime:(NSTimeInterval)time {
    if (riskState == FaceRiskStateNone) {
        [self reset];
        return NO;
    }

    if (riskState == FaceRiskStateBorderline) {
        if (!self.hasFirstRiskTime) return NO;
        self.consecutiveBorderlineFrames += 1;
        if (self.consecutiveBorderlineFrames >= 2) [self reset];
        return NO;
    }

    self.consecutiveBorderlineFrames = 0;
    if (self.didTriggerForCurrentPresence) {
        return NO;
    }
    if (!self.hasFirstRiskTime) {
        self.firstRiskTime = time;
        self.hasFirstRiskTime = YES;
        return NO;
    }
    if (time - self.firstRiskTime < self.requiredDuration) {
        return NO;
    }
    self.didTriggerForCurrentPresence = YES;
    return YES;
}

- (void)reset {
    self.firstRiskTime = 0;
    self.hasFirstRiskTime = NO;
    self.didTriggerForCurrentPresence = NO;
    self.consecutiveBorderlineFrames = 0;
}

@end

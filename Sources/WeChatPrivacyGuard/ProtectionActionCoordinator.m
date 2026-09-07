#import "ProtectionActionCoordinator.h"

static const NSTimeInterval OverlayRecoveryDelay = 1.0;
static const NSTimeInterval TestOverlayDuration = 3.0;

@interface ProtectionActionCoordinator ()
@property(nonatomic, strong) id<PrivacyOverlayManaging> overlayController;
@property(nonatomic, copy) BOOL (^hideHandler)(NSString *bundleIdentifier);
@property(nonatomic, readwrite) ProtectionActionState state;
@property(nonatomic) NSTimeInterval recoveryDeadline;
@property(nonatomic) NSTimeInterval testDeadline;
@property(nonatomic) BOOL recoveryScheduled;
@property(nonatomic) BOOL testOverlayActive;
@property(nonatomic) BOOL usedHideFallback;
@property(nonatomic, copy) NSSet<NSString *> *bundleIdentifiers;
@property(nonatomic, strong, nullable) NSTimer *deadlineTimer;
- (void)clearOverlayAnimated:(BOOL)animated;
@end

@implementation ProtectionActionCoordinator

- (instancetype)initWithOverlayController:(id<PrivacyOverlayManaging>)overlayController
                               hideHandler:(BOOL (^)(NSString *bundleIdentifier))hideHandler {
    self = [super init];
    if (self) {
        _overlayController = overlayController;
        _hideHandler = [hideHandler copy];
        _protectionMode = ProtectionModeHideWindows;
        _state = ProtectionActionStateIdle;
        _bundleIdentifiers = [NSSet set];
        __weak typeof(self) weakSelf = self;
        _overlayController.fallbackHandler = ^(NSString *bundleIdentifier) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.usedHideFallback = YES;
            self.hideHandler(bundleIdentifier);
            [self publishState];
        };
    }
    return self;
}

- (BOOL)canClearOverlay {
    return self.overlayController.overlayCount > 0 ||
        self.state == ProtectionActionStateOverlayActive ||
        self.state == ProtectionActionStateWaitingForRecovery;
}

- (void)setProtectionMode:(ProtectionMode)protectionMode {
    _protectionMode = protectionMode == ProtectionModePrivacyOverlay
        ? ProtectionModePrivacyOverlay : ProtectionModeHideWindows;
    [self clearOverlayAnimated:NO];
    self.state = ProtectionActionStateIdle;
    [self publishState];
}

- (void)handleRiskState:(FaceRiskState)riskState
             didTrigger:(BOOL)didTrigger
                  atTime:(NSTimeInterval)time
       bundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers {
    self.bundleIdentifiers = [bundleIdentifiers copy];
    [self.overlayController updateBundleIdentifiers:self.bundleIdentifiers];
    [self advanceToTime:time];

    if (didTrigger) {
        self.testOverlayActive = NO;
        self.testDeadline = 0;
        if (self.protectionMode == ProtectionModeHideWindows) {
            [self.overlayController deactivateAnimated:NO];
            for (NSString *bundleIdentifier in self.bundleIdentifiers) self.hideHandler(bundleIdentifier);
            self.state = ProtectionActionStateHidden;
            [self cancelDeadlineTimer];
        } else {
            self.usedHideFallback = NO;
            [self.overlayController activateForBundleIdentifiers:self.bundleIdentifiers];
            self.state = ProtectionActionStateOverlayActive;
            self.recoveryScheduled = NO;
        }
        [self publishState];
        return;
    }

    if (self.testOverlayActive) return;

    if (self.state == ProtectionActionStateHidden) {
        if (riskState == FaceRiskStateNone) {
            self.state = ProtectionActionStateIdle;
            [self publishState];
        }
        return;
    }

    if (self.state == ProtectionActionStateOverlayActive) {
        if (riskState == FaceRiskStateNone) {
            self.state = ProtectionActionStateWaitingForRecovery;
            self.recoveryScheduled = YES;
            self.recoveryDeadline = time + OverlayRecoveryDelay;
            [self scheduleDeadlineTimer:OverlayRecoveryDelay];
            [self publishState];
        }
        return;
    }

    if (self.state == ProtectionActionStateWaitingForRecovery && riskState != FaceRiskStateNone) {
        self.recoveryScheduled = NO;
        self.recoveryDeadline = 0;
        self.state = ProtectionActionStateOverlayActive;
        [self cancelDeadlineTimer];
        [self publishState];
    }
}

- (void)testProtectionAtTime:(NSTimeInterval)time
            bundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers {
    self.bundleIdentifiers = [bundleIdentifiers copy];
    [self cancelDeadlineTimer];
    if (self.protectionMode == ProtectionModeHideWindows) {
        for (NSString *bundleIdentifier in self.bundleIdentifiers) self.hideHandler(bundleIdentifier);
        self.state = ProtectionActionStateHidden;
        [self publishState];
        return;
    }

    self.usedHideFallback = NO;
    self.testOverlayActive = YES;
    self.testDeadline = time + TestOverlayDuration;
    self.recoveryScheduled = NO;
    [self.overlayController activateForBundleIdentifiers:self.bundleIdentifiers];
    self.state = ProtectionActionStateOverlayActive;
    [self scheduleDeadlineTimer:TestOverlayDuration];
    [self publishState];
}

- (void)advanceToTime:(NSTimeInterval)time {
    if (self.testOverlayActive && time >= self.testDeadline) {
        [self finishOverlay];
        return;
    }
    if (self.recoveryScheduled && time >= self.recoveryDeadline) [self finishOverlay];
}

- (void)updateBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers {
    self.bundleIdentifiers = [bundleIdentifiers copy];
    [self.overlayController updateBundleIdentifiers:self.bundleIdentifiers];
}

- (void)clearOverlay {
    [self clearOverlayAnimated:YES];
}

- (void)clearOverlayAnimated:(BOOL)animated {
    [self.overlayController deactivateAnimated:animated];
    [self cancelDeadlineTimer];
    self.testOverlayActive = NO;
    self.testDeadline = 0;
    self.recoveryScheduled = NO;
    self.recoveryDeadline = 0;
    self.usedHideFallback = NO;
    if (self.state == ProtectionActionStateOverlayActive ||
        self.state == ProtectionActionStateWaitingForRecovery) {
        self.state = ProtectionActionStateIdle;
    }
    [self publishState];
}

- (void)stop {
    [self clearOverlayAnimated:NO];
    self.state = ProtectionActionStateIdle;
    [self publishState];
}

- (void)finishOverlay {
    [self.overlayController deactivateAnimated:YES];
    [self cancelDeadlineTimer];
    self.testOverlayActive = NO;
    self.testDeadline = 0;
    self.recoveryScheduled = NO;
    self.recoveryDeadline = 0;
    self.usedHideFallback = NO;
    self.state = ProtectionActionStateIdle;
    [self publishState];
}

- (void)scheduleDeadlineTimer:(NSTimeInterval)delay {
    [self cancelDeadlineTimer];
    __weak typeof(self) weakSelf = self;
    self.deadlineTimer = [NSTimer scheduledTimerWithTimeInterval:delay repeats:NO block:^(NSTimer *timer) {
        [weakSelf advanceToTime:NSProcessInfo.processInfo.systemUptime];
    }];
    self.deadlineTimer.tolerance = MIN(0.1, delay * 0.1);
}

- (void)cancelDeadlineTimer {
    [self.deadlineTimer invalidate];
    self.deadlineTimer = nil;
}

- (void)publishState {
    NSString *message = nil;
    if (self.usedHideFallback) {
        message = @"遮罩失败，已改为隐藏";
    } else if (self.state == ProtectionActionStateOverlayActive ||
               self.state == ProtectionActionStateWaitingForRecovery) {
        message = @"隐私遮罩中";
    }
    if (self.stateDidChange) self.stateDidChange(self.state, message, self.canClearOverlay);
}

@end

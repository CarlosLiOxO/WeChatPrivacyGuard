#import "EnergyStateCoordinator.h"

@interface EnergyStateCoordinator ()
@property(nonatomic, readwrite) EnergyState state;
@property(nonatomic, readwrite) BOOL cameraShouldRun;
@property(nonatomic, readwrite) NSTimeInterval windowMonitoringInterval;
@property(nonatomic, copy, readwrite) NSString *statusText;
@end

@implementation EnergyStateCoordinator

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = EnergyStateDisabled;
        _statusText = @"保护已暂停";
    }
    return self;
}

- (void)updateWithProtectionEnabled:(BOOL)protectionEnabled
                     systemAvailable:(BOOL)systemAvailable
                    enrollmentActive:(BOOL)enrollmentActive
                    windowVisibility:(ProtectedWindowVisibility)windowVisibility {
    if (enrollmentActive) {
        self.state = EnergyStateEnrollment;
        self.cameraShouldRun = YES;
        self.windowMonitoringInterval = 0;
        self.statusText = @"正在录入本人面容";
        return;
    }
    if (!protectionEnabled) {
        self.state = EnergyStateDisabled;
        self.cameraShouldRun = NO;
        self.windowMonitoringInterval = 0;
        self.statusText = @"保护已暂停";
        return;
    }
    if (!systemAvailable) {
        self.state = EnergyStateSystemPaused;
        self.cameraShouldRun = NO;
        self.windowMonitoringInterval = 0;
        self.statusText = @"保护已暂停 · 屏幕锁定";
        return;
    }
    if (windowVisibility == ProtectedWindowVisibilityNotVisible) {
        self.state = EnergyStateNoVisibleWindows;
        self.cameraShouldRun = NO;
        self.windowMonitoringInterval = 1.0;
        self.statusText = @"智能节能中 · 受保护窗口不可见";
        return;
    }

    self.state = EnergyStateFullProtection;
    self.cameraShouldRun = YES;
    self.windowMonitoringInterval = 2.0;
    self.statusText = @"保护中";
}

@end

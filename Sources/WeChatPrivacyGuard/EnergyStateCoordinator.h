#import <Foundation/Foundation.h>
#import "ProtectedWindowActivityMonitor.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, EnergyState) {
    EnergyStateDisabled = 0,
    EnergyStateFullProtection = 1,
    EnergyStateNoVisibleWindows = 2,
    EnergyStateSystemPaused = 3,
    EnergyStateEnrollment = 4,
};

@interface EnergyStateCoordinator : NSObject

@property(nonatomic, readonly) EnergyState state;
@property(nonatomic, readonly) BOOL cameraShouldRun;
@property(nonatomic, readonly) NSTimeInterval windowMonitoringInterval;
@property(nonatomic, copy, readonly) NSString *statusText;

- (void)updateWithProtectionEnabled:(BOOL)protectionEnabled
                     systemAvailable:(BOOL)systemAvailable
                    enrollmentActive:(BOOL)enrollmentActive
                    windowVisibility:(ProtectedWindowVisibility)windowVisibility;

@end

NS_ASSUME_NONNULL_END

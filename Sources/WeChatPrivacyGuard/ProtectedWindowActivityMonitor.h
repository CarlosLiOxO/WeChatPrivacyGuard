#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ProtectedWindowVisibility) {
    ProtectedWindowVisibilityUnknown = 0,
    ProtectedWindowVisibilityNotVisible = 1,
    ProtectedWindowVisibilityVisible = 2,
};

FOUNDATION_EXPORT ProtectedWindowVisibility ProtectedWindowVisibilityFromWindowInfo(
    NSArray<NSDictionary *> * _Nullable windowInfo,
    NSDictionary<NSNumber *, NSString *> *processIdentifiers,
    NSSet<NSString *> *protectedBundleIdentifiers,
    NSSet<NSNumber *> *ignoredOccluderProcessIdentifiers);

@interface ProtectedWindowActivityMonitor : NSObject

@property(nonatomic, readonly) ProtectedWindowVisibility currentVisibility;
@property(nonatomic, readonly) NSTimeInterval monitoringInterval;
@property(nonatomic, copy, nullable) void (^visibilityDidChange)(ProtectedWindowVisibility visibility);

- (instancetype)initWithProtectedBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers;
- (void)updateProtectedBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers;
- (ProtectedWindowVisibility)checkNow;
- (void)startMonitoringWithInterval:(NSTimeInterval)interval;
- (void)stopMonitoring;

@end

NS_ASSUME_NONNULL_END

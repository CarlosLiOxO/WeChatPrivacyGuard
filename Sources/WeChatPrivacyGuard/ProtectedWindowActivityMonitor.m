#import "ProtectedWindowActivityMonitor.h"
#import <CoreGraphics/CoreGraphics.h>
#import <math.h>

static BOOL WindowGeometry(NSDictionary *window, CGRect *bounds, CGFloat *alpha) {
    NSNumber *layer = window[(id)kCGWindowLayer];
    NSNumber *windowAlpha = window[(id)kCGWindowAlpha];
    NSDictionary *boundsDictionary = window[(id)kCGWindowBounds];
    CGRect parsedBounds = CGRectZero;
    BOOL validBounds = boundsDictionary && CGRectMakeWithDictionaryRepresentation(
        (__bridge CFDictionaryRef)boundsDictionary, &parsedBounds);
    if (layer.integerValue != 0 || !windowAlpha || !validBounds ||
        !isfinite(CGRectGetMinX(parsedBounds)) || !isfinite(CGRectGetMinY(parsedBounds)) ||
        !isfinite(CGRectGetWidth(parsedBounds)) || !isfinite(CGRectGetHeight(parsedBounds)) ||
        CGRectGetWidth(parsedBounds) <= 0 || CGRectGetHeight(parsedBounds) <= 0) return NO;
    if (bounds) *bounds = CGRectStandardize(parsedBounds);
    if (alpha) *alpha = windowAlpha.doubleValue;
    return YES;
}

static NSArray<NSValue *> *VisibleFragmentsAfterSubtractingRect(
    NSArray<NSValue *> *fragments, CGRect cover) {
    NSMutableArray<NSValue *> *remaining = [NSMutableArray array];
    for (NSValue *value in fragments) {
        CGRect source = value.rectValue;
        CGRect intersection = CGRectIntersection(source, cover);
        if (CGRectIsNull(intersection) || CGRectIsEmpty(intersection)) {
            [remaining addObject:value];
            continue;
        }
        CGFloat sourceMinX = CGRectGetMinX(source);
        CGFloat sourceMaxX = CGRectGetMaxX(source);
        CGFloat sourceMinY = CGRectGetMinY(source);
        CGFloat sourceMaxY = CGRectGetMaxY(source);
        CGFloat cutMinX = CGRectGetMinX(intersection);
        CGFloat cutMaxX = CGRectGetMaxX(intersection);
        CGFloat cutMinY = CGRectGetMinY(intersection);
        CGFloat cutMaxY = CGRectGetMaxY(intersection);
        CGRect pieces[] = {
            CGRectMake(sourceMinX, sourceMinY, CGRectGetWidth(source), cutMinY - sourceMinY),
            CGRectMake(sourceMinX, cutMaxY, CGRectGetWidth(source), sourceMaxY - cutMaxY),
            CGRectMake(sourceMinX, cutMinY, cutMinX - sourceMinX, CGRectGetHeight(intersection)),
            CGRectMake(cutMaxX, cutMinY, sourceMaxX - cutMaxX, CGRectGetHeight(intersection)),
        };
        for (NSUInteger index = 0; index < 4; index++) {
            if (CGRectGetWidth(pieces[index]) > 0 && CGRectGetHeight(pieces[index]) > 0) {
                [remaining addObject:[NSValue valueWithRect:pieces[index]]];
            }
        }
    }
    return remaining.copy;
}

static BOOL WindowHasVisibleArea(CGRect target, NSArray<NSValue *> *opaqueWindowsInFront) {
    NSArray<NSValue *> *fragments = @[[NSValue valueWithRect:target]];
    for (NSValue *cover in opaqueWindowsInFront) {
        fragments = VisibleFragmentsAfterSubtractingRect(fragments, cover.rectValue);
        if (fragments.count == 0) return NO;
        // Pathological window arrangements must not create unbounded geometry
        // work. If visibility becomes too complex to prove, keep protection on.
        if (fragments.count > 256) return YES;
    }
    return fragments.count > 0;
}

ProtectedWindowVisibility ProtectedWindowVisibilityFromWindowInfo(
    NSArray<NSDictionary *> *windowInfo,
    NSDictionary<NSNumber *, NSString *> *processIdentifiers,
    NSSet<NSString *> *protectedBundleIdentifiers,
    NSSet<NSNumber *> *ignoredOccluderProcessIdentifiers) {
    if (!windowInfo) return ProtectedWindowVisibilityUnknown;
    NSMutableArray<NSValue *> *opaqueWindowsInFront = [NSMutableArray array];
    // CGWindowListCopyWindowInfo returns windows front-to-back. A protected
    // window remains visible in split screen or behind a smaller window as long
    // as the union of opaque windows in front does not cover its whole bounds.
    for (NSDictionary *window in windowInfo) {
        NSNumber *ownerPID = window[(id)kCGWindowOwnerPID];
        NSString *bundleIdentifier = processIdentifiers[ownerPID];
        CGRect bounds = CGRectZero;
        CGFloat alpha = 0;
        if (!WindowGeometry(window, &bounds, &alpha)) continue;
        BOOL isProtectedWindow = [protectedBundleIdentifiers containsObject:bundleIdentifier];
        if (isProtectedWindow && alpha > 0 && CGRectGetWidth(bounds) >= 40 &&
            CGRectGetHeight(bounds) >= 40 &&
            WindowHasVisibleArea(bounds, opaqueWindowsInFront)) {
            return ProtectedWindowVisibilityVisible;
        }
        // Only fully opaque normal windows can prove that a target behind them
        // is invisible. Treat uncertain/translucent geometry conservatively.
        if (alpha >= 0.99 && ![ignoredOccluderProcessIdentifiers containsObject:ownerPID]) {
            [opaqueWindowsInFront addObject:[NSValue valueWithRect:bounds]];
        }
    }
    return ProtectedWindowVisibilityNotVisible;
}

@interface ProtectedWindowActivityMonitor ()
@property(nonatomic, copy) NSSet<NSString *> *protectedBundleIdentifiers;
@property(nonatomic, readwrite) ProtectedWindowVisibility currentVisibility;
@property(nonatomic, readwrite) NSTimeInterval monitoringInterval;
@property(nonatomic, strong, nullable) NSTimer *monitoringTimer;
@end

@implementation ProtectedWindowActivityMonitor

- (instancetype)initWithProtectedBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers {
    self = [super init];
    if (self) {
        _protectedBundleIdentifiers = [bundleIdentifiers copy];
        _currentVisibility = ProtectedWindowVisibilityUnknown;
        NSNotificationCenter *workspaceCenter = NSWorkspace.sharedWorkspace.notificationCenter;
        NSArray<NSNotificationName> *names = @[
            NSWorkspaceDidLaunchApplicationNotification,
            NSWorkspaceDidTerminateApplicationNotification,
            NSWorkspaceDidActivateApplicationNotification,
            NSWorkspaceDidHideApplicationNotification,
            NSWorkspaceDidUnhideApplicationNotification,
        ];
        for (NSNotificationName name in names) {
            [workspaceCenter addObserver:self selector:@selector(workspaceApplicationDidChange:)
                                    name:name object:nil];
        }
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}

- (void)updateProtectedBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers {
    self.protectedBundleIdentifiers = [bundleIdentifiers copy];
    [self checkNow];
}

- (ProtectedWindowVisibility)checkNow {
    NSMutableDictionary<NSNumber *, NSString *> *processIdentifiers = [NSMutableDictionary dictionary];
    for (NSString *bundleIdentifier in self.protectedBundleIdentifiers) {
        for (NSRunningApplication *application in
             [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier]) {
            processIdentifiers[@(application.processIdentifier)] = bundleIdentifier;
        }
    }

    ProtectedWindowVisibility visibility = ProtectedWindowVisibilityNotVisible;
    if (processIdentifiers.count > 0) {
        CFArrayRef rawWindowInfo = CGWindowListCopyWindowInfo(
            kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
        NSArray<NSDictionary *> *windowInfo = rawWindowInfo
            ? CFBridgingRelease(rawWindowInfo) : nil;
        visibility = ProtectedWindowVisibilityFromWindowInfo(
            windowInfo, processIdentifiers, self.protectedBundleIdentifiers,
            [NSSet setWithObject:@(NSProcessInfo.processInfo.processIdentifier)]);
    }

    BOOL changed = visibility != self.currentVisibility;
    self.currentVisibility = visibility;
    if (changed && self.visibilityDidChange) self.visibilityDidChange(visibility);
    return visibility;
}

- (void)startMonitoringWithInterval:(NSTimeInterval)interval {
    NSTimeInterval validated = MAX(0.25, interval);
    if (self.monitoringTimer && fabs(self.monitoringInterval - validated) < 0.001) return;
    [self.monitoringTimer invalidate];
    self.monitoringInterval = validated;
    __weak typeof(self) weakSelf = self;
    self.monitoringTimer = [NSTimer scheduledTimerWithTimeInterval:validated repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf checkNow];
    }];
    self.monitoringTimer.tolerance = MIN(0.2, validated * 0.15);
}

- (void)stopMonitoring {
    [self.monitoringTimer invalidate];
    self.monitoringTimer = nil;
    self.monitoringInterval = 0;
}

- (void)workspaceApplicationDidChange:(NSNotification *)notification {
    (void)notification;
    if (self.monitoringTimer) [self checkNow];
}

@end

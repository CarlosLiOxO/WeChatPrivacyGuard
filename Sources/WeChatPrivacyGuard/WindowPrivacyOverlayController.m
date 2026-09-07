#import "WindowPrivacyOverlayController.h"
#import "PrivacyOverlayMaterialView.h"
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

@implementation ProtectedWindowDescriptor

- (instancetype)initWithWindowNumber:(CGWindowID)windowNumber
                   processIdentifier:(pid_t)processIdentifier
                    bundleIdentifier:(NSString *)bundleIdentifier
                        quartzBounds:(CGRect)quartzBounds {
    self = [super init];
    if (self) {
        _windowNumber = windowNumber;
        _processIdentifier = processIdentifier;
        _bundleIdentifier = [bundleIdentifier copy];
        _quartzBounds = quartzBounds;
    }
    return self;
}

@end

@implementation WindowMetadataFilter

+ (NSArray<ProtectedWindowDescriptor *> *)descriptorsFromWindowInfo:(NSArray<NSDictionary *> *)windowInfo
                                                 processIdentifiers:(NSDictionary<NSNumber *, NSString *> *)processIdentifiers {
    NSMutableArray<ProtectedWindowDescriptor *> *result = [NSMutableArray array];
    for (NSDictionary *window in windowInfo) {
        NSNumber *ownerPID = window[(id)kCGWindowOwnerPID];
        NSString *bundleIdentifier = processIdentifiers[ownerPID];
        if (!bundleIdentifier) continue;

        NSNumber *windowNumber = window[(id)kCGWindowNumber];
        NSNumber *layer = window[(id)kCGWindowLayer];
        NSNumber *alpha = window[(id)kCGWindowAlpha];
        NSDictionary *boundsDictionary = window[(id)kCGWindowBounds];
        CGRect bounds = CGRectZero;
        BOOL validBounds = boundsDictionary && CGRectMakeWithDictionaryRepresentation(
            (__bridge CFDictionaryRef)boundsDictionary, &bounds);
        if (!windowNumber || windowNumber.unsignedIntValue == 0 || layer.integerValue != 0 ||
            alpha.doubleValue <= 0 || !validBounds || CGRectGetWidth(bounds) < 40 || CGRectGetHeight(bounds) < 40) {
            continue;
        }

        [result addObject:[[ProtectedWindowDescriptor alloc]
            initWithWindowNumber:windowNumber.unsignedIntValue
            processIdentifier:ownerPID.intValue
            bundleIdentifier:bundleIdentifier
            quartzBounds:bounds]];
    }
    return result;
}

@end

@interface PrivacyOverlayPanel : NSPanel
@end

@implementation PrivacyOverlayPanel
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface PrivacyOverlayEntry : NSObject
@property(nonatomic, strong) PrivacyOverlayPanel *panel;
@property(nonatomic, copy) NSString *bundleIdentifier;
@end
@implementation PrivacyOverlayEntry
@end

@interface WindowPrivacyOverlayController ()
@property(nonatomic, copy) NSSet<NSString *> *bundleIdentifiers;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, PrivacyOverlayEntry *> *entries;
@property(nonatomic, strong) NSMutableSet<NSString *> *failedBundleIdentifiers;
@property(nonatomic, strong) NSMutableSet<NSString *> *temporarilyRevealedBundleIdentifiers;
@property(nonatomic, strong, nullable) NSTimer *refreshTimer;
@property(nonatomic) BOOL active;
@end

@implementation WindowPrivacyOverlayController

- (instancetype)init {
    self = [super init];
    if (self) {
        _bundleIdentifiers = [NSSet set];
        _entries = [NSMutableDictionary dictionary];
        _failedBundleIdentifiers = [NSMutableSet set];
        _temporarilyRevealedBundleIdentifiers = [NSMutableSet set];
    }
    return self;
}

- (NSUInteger)overlayCount {
    return self.entries.count;
}

- (void)activateForBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers {
    self.active = YES;
    self.bundleIdentifiers = [bundleIdentifiers copy];
    [self.failedBundleIdentifiers removeAllObjects];
    [self.temporarilyRevealedBundleIdentifiers removeAllObjects];
    [self refreshNow];
    [self.refreshTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        [weakSelf refreshNow];
    }];
    self.refreshTimer.tolerance = 0.025;
}

- (void)updateBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers {
    self.bundleIdentifiers = [bundleIdentifiers copy];
    if (self.active) [self refreshNow];
}

- (void)deactivateAnimated:(BOOL)animated {
    self.active = NO;
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    NSArray<PrivacyOverlayEntry *> *closingEntries = self.entries.allValues.copy;
    [self.entries removeAllObjects];
    [self.failedBundleIdentifiers removeAllObjects];
    [self.temporarilyRevealedBundleIdentifiers removeAllObjects];
    [self publishOverlayCount];
    for (PrivacyOverlayEntry *entry in closingEntries) {
        PrivacyOverlayPanel *panel = entry.panel;
        if (!animated || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
            [panel close];
            continue;
        }
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.22;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
            panel.animator.alphaValue = 0;
        } completionHandler:^{
            [panel close];
        }];
    }
}

- (void)refreshNow {
    if (!self.active) return;
    NSDictionary<NSNumber *, NSString *> *processIdentifiers = [self processIdentifiersByBundleIdentifier];
    CFArrayRef rawWindowInfo = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    NSArray<NSDictionary *> *windowInfo = CFBridgingRelease(rawWindowInfo) ?: @[];
    NSArray<ProtectedWindowDescriptor *> *descriptors =
        [WindowMetadataFilter descriptorsFromWindowInfo:windowInfo processIdentifiers:processIdentifiers];

    NSMutableSet<NSNumber *> *visibleWindowNumbers = [NSMutableSet set];
    for (ProtectedWindowDescriptor *descriptor in descriptors) {
        NSNumber *key = @(descriptor.windowNumber);
        [visibleWindowNumbers addObject:key];
        if ([self.temporarilyRevealedBundleIdentifiers containsObject:descriptor.bundleIdentifier]) continue;
        PrivacyOverlayEntry *entry = self.entries[key];
        @try {
            if (!entry) {
                entry = [[PrivacyOverlayEntry alloc] init];
                entry.bundleIdentifier = descriptor.bundleIdentifier;
                entry.panel = [self createPanelForWindowNumber:descriptor.windowNumber
                                               bundleIdentifier:descriptor.bundleIdentifier];
                entry.panel.alphaValue = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion ? 1 : 0;
                self.entries[key] = entry;
            }
            NSRect frame = [self appKitFrameFromQuartzBounds:descriptor.quartzBounds];
            if (NSWidth(frame) < 40 || NSHeight(frame) < 40 || !isfinite(NSMinX(frame)) || !isfinite(NSMinY(frame))) {
                @throw [NSException exceptionWithName:@"InvalidOverlayFrame" reason:@"窗口边界无效" userInfo:nil];
            }
            [entry.panel setFrame:frame display:YES];
            [entry.panel orderWindow:NSWindowAbove relativeTo:(NSInteger)descriptor.windowNumber];
            if (entry.panel.alphaValue < 1) {
                [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                    context.duration = 0.18;
                    context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
                    entry.panel.animator.alphaValue = 1;
                } completionHandler:nil];
            }
        } @catch (NSException *exception) {
            [entry.panel close];
            [self.entries removeObjectForKey:key];
            [self handleFailureForBundleIdentifier:descriptor.bundleIdentifier];
        }
    }

    for (NSNumber *key in self.entries.allKeys.copy) {
        if (![visibleWindowNumbers containsObject:key]) {
            [self.entries[key].panel close];
            [self.entries removeObjectForKey:key];
        }
    }
    [self publishOverlayCount];
}

- (NSDictionary<NSNumber *, NSString *> *)processIdentifiersByBundleIdentifier {
    NSMutableDictionary<NSNumber *, NSString *> *result = [NSMutableDictionary dictionary];
    for (NSString *bundleIdentifier in self.bundleIdentifiers) {
        for (NSRunningApplication *application in
             [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier]) {
            if (application.processIdentifier != NSProcessInfo.processInfo.processIdentifier) {
                result[@(application.processIdentifier)] = bundleIdentifier;
            }
        }
    }
    return result;
}

- (PrivacyOverlayPanel *)createPanelForWindowNumber:(CGWindowID)windowNumber
                                    bundleIdentifier:(NSString *)bundleIdentifier {
    PrivacyOverlayPanel *panel = [[PrivacyOverlayPanel alloc]
        initWithContentRect:NSMakeRect(0, 0, 100, 100)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    panel.opaque = NO;
    panel.backgroundColor = NSColor.clearColor;
    panel.hasShadow = YES;
    panel.hidesOnDeactivate = NO;
    panel.ignoresMouseEvents = NO;
    panel.releasedWhenClosed = NO;
    panel.collectionBehavior = NSWindowCollectionBehaviorFullScreenAuxiliary |
        NSWindowCollectionBehaviorTransient |
        NSWindowCollectionBehaviorIgnoresCycle;
    PrivacyOverlayMaterialView *view = [[PrivacyOverlayMaterialView alloc] initWithFrame:panel.contentView.bounds];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    view.accessibilityLabel = @"隐私保护遮罩";
    __weak typeof(self) weakSelf = self;
    view.temporaryRevealHandler = ^{
        [weakSelf temporarilyRevealBundleIdentifier:bundleIdentifier];
    };
    panel.contentView = view;
    return panel;
}

- (void)temporarilyRevealBundleIdentifier:(NSString *)bundleIdentifier {
    if (bundleIdentifier.length == 0) return;
    [self.temporarilyRevealedBundleIdentifiers addObject:bundleIdentifier];
    for (NSNumber *key in self.entries.allKeys.copy) {
        PrivacyOverlayEntry *entry = self.entries[key];
        if (![entry.bundleIdentifier isEqualToString:bundleIdentifier]) continue;
        [entry.panel close];
        [self.entries removeObjectForKey:key];
    }
    [self publishOverlayCount];
}

- (BOOL)isBundleIdentifierTemporarilyRevealed:(NSString *)bundleIdentifier {
    return [self.temporarilyRevealedBundleIdentifiers containsObject:bundleIdentifier];
}

- (NSRect)appKitFrameFromQuartzBounds:(CGRect)bounds {
    NSScreen *mainScreen = NSScreen.screens.firstObject ?: NSScreen.mainScreen;
    CGFloat mainScreenHeight = NSHeight(mainScreen.frame);
    return NSMakeRect(CGRectGetMinX(bounds),
                      mainScreenHeight - CGRectGetMinY(bounds) - CGRectGetHeight(bounds),
                      CGRectGetWidth(bounds), CGRectGetHeight(bounds));
}

- (void)handleFailureForBundleIdentifier:(NSString *)bundleIdentifier {
    if ([self.failedBundleIdentifiers containsObject:bundleIdentifier]) return;
    [self.failedBundleIdentifiers addObject:bundleIdentifier];
    if (self.fallbackHandler) self.fallbackHandler(bundleIdentifier);
}

- (void)publishOverlayCount {
    if (self.overlayCountDidChange) self.overlayCountDidChange(self.overlayCount);
}

@end

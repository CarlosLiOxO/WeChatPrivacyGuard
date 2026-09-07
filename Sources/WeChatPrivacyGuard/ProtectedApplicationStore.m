#import "ProtectedApplicationStore.h"

static NSString *const SelectedBundleIDKey = @"extraProtectedBundleIdentifier";
static NSString *const SelectedDisplayNameKey = @"extraProtectedDisplayName";
static NSString *const SelectedPathKey = @"extraProtectedApplicationPath";

@implementation ProtectedApplicationStore

- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        _defaults = defaults;
    }
    return self;
}

- (ProtectedApplication *)selectedApplication {
    NSString *bundleIdentifier = [self.defaults stringForKey:SelectedBundleIDKey];
    NSString *displayName = [self.defaults stringForKey:SelectedDisplayNameKey];
    NSString *path = [self.defaults stringForKey:SelectedPathKey];
    if (bundleIdentifier.length == 0 || displayName.length == 0 || path.length == 0) return nil;
    return [[ProtectedApplication alloc]
        initWithBundleIdentifier:bundleIdentifier
                     displayName:displayName
                  applicationURL:[NSURL fileURLWithPath:path]];
}

- (void)saveApplication:(ProtectedApplication *)application {
    [self.defaults setObject:application.bundleIdentifier forKey:SelectedBundleIDKey];
    [self.defaults setObject:application.displayName forKey:SelectedDisplayNameKey];
    [self.defaults setObject:application.applicationURL.path forKey:SelectedPathKey];
}

- (void)clear {
    [self.defaults removeObjectForKey:SelectedBundleIDKey];
    [self.defaults removeObjectForKey:SelectedDisplayNameKey];
    [self.defaults removeObjectForKey:SelectedPathKey];
}

@end

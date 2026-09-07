#import "ProtectedApplication.h"

@implementation ProtectedApplication

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                              displayName:(NSString *)displayName
                           applicationURL:(NSURL *)applicationURL {
    self = [super init];
    if (self) {
        _bundleIdentifier = [bundleIdentifier copy];
        _displayName = [displayName copy];
        _applicationURL = applicationURL;
    }
    return self;
}

- (NSImage *)icon {
    NSImage *icon = [NSWorkspace.sharedWorkspace iconForFile:self.applicationURL.path];
    icon.size = NSMakeSize(16, 16);
    return icon;
}

@end

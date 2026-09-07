#import "ApplicationVisibilityController.h"
#import <AppKit/AppKit.h>

@implementation ApplicationVisibilityController

+ (BOOL)hideApplicationWithBundleIdentifier:(NSString *)bundleIdentifier {
    NSArray<NSRunningApplication *> *applications =
        [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
    BOOL succeeded = YES;
    for (NSRunningApplication *application in applications) {
        succeeded = [application hide] && succeeded;
    }
    return succeeded;
}

+ (void)openOrActivateBundleIdentifier:(NSString *)bundleIdentifier {
    NSRunningApplication *application =
        [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier].firstObject;
    if (application) {
        [application unhide];
        [application activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];
        return;
    }

    NSURL *url = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:bundleIdentifier];
    if (!url) return;
    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
    configuration.activates = YES;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:url
                                        configuration:configuration
                                    completionHandler:nil];
}

@end

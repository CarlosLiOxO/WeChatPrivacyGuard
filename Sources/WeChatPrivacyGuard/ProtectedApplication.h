#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProtectedApplication : NSObject

@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@property(nonatomic, copy, readonly) NSString *displayName;
@property(nonatomic, strong, readonly) NSURL *applicationURL;

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                              displayName:(NSString *)displayName
                           applicationURL:(NSURL *)applicationURL;
- (NSImage *)icon;

@end

NS_ASSUME_NONNULL_END

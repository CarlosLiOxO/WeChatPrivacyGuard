#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ApplicationVisibilityController : NSObject
+ (BOOL)hideApplicationWithBundleIdentifier:(NSString *)bundleIdentifier;
+ (void)openOrActivateBundleIdentifier:(NSString *)bundleIdentifier;
@end

NS_ASSUME_NONNULL_END

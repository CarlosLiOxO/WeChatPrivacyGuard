#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ProtectionMode) {
    ProtectionModeHideWindows = 0,
    ProtectionModePrivacyOverlay = 1,
};

@interface ProtectionModeStore : NSObject

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults;
- (ProtectionMode)protectionMode;
- (void)saveProtectionMode:(ProtectionMode)mode;

@end

NS_ASSUME_NONNULL_END

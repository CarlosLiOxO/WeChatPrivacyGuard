#import "ProtectionModeStore.h"

static NSString *const ProtectionModeDefaultsKey = @"protectionMode";

@interface ProtectionModeStore ()
@property(nonatomic, strong) NSUserDefaults *userDefaults;
@end

@implementation ProtectionModeStore

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
    self = [super init];
    if (self) _userDefaults = userDefaults;
    return self;
}

- (ProtectionMode)protectionMode {
    NSNumber *stored = [self.userDefaults objectForKey:ProtectionModeDefaultsKey];
    if (!stored) return ProtectionModeHideWindows;
    NSInteger value = stored.integerValue;
    if (value != ProtectionModeHideWindows && value != ProtectionModePrivacyOverlay) {
        return ProtectionModeHideWindows;
    }
    return value;
}

- (void)saveProtectionMode:(ProtectionMode)mode {
    ProtectionMode validated = mode == ProtectionModePrivacyOverlay
        ? ProtectionModePrivacyOverlay : ProtectionModeHideWindows;
    [self.userDefaults setInteger:validated forKey:ProtectionModeDefaultsKey];
}

@end

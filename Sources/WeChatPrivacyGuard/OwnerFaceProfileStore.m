#import "OwnerFaceProfileStore.h"
#import <Security/Security.h>

static NSString *const OwnerFaceProfileService = @"com.carlosli.WeChatPrivacyGuard.owner-face-profile";
static NSString *const OwnerFaceProfileAccount = @"current-user";
static NSString *const OwnerFaceKeychainErrorDomain = @"com.carlosli.WeChatPrivacyGuard.OwnerFaceKeychain";

static NSError *OwnerFaceKeychainError(OSStatus status, NSString *operation) {
    NSString *statusMessage = CFBridgingRelease(SecCopyErrorMessageString(status, NULL)) ?: @"未知错误";
    return [NSError errorWithDomain:OwnerFaceKeychainErrorDomain code:status
                           userInfo:@{NSLocalizedDescriptionKey:
        [NSString stringWithFormat:@"%@失败：%@", operation, statusMessage]}];
}

static NSDictionary *OwnerFaceBaseQuery(NSString *service, NSString *account) {
    return @{
        (id)kSecClass: (id)kSecClassGenericPassword,
        (id)kSecAttrService: service,
        (id)kSecAttrAccount: account,
        (id)kSecAttrSynchronizable: @NO,
    };
}

@implementation SystemOwnerFaceKeychainClient

- (NSData *)dataForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
    NSMutableDictionary *query = [OwnerFaceBaseQuery(service, account) mutableCopy];
    query[(id)kSecReturnData] = @YES;
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) return nil;
    if (status != errSecSuccess) {
        if (error) *error = OwnerFaceKeychainError(status, @"读取本人特征");
        if (result) CFRelease(result);
        return nil;
    }
    return CFBridgingRelease(result);
}

- (BOOL)setData:(NSData *)data service:(NSString *)service account:(NSString *)account error:(NSError **)error {
    NSDictionary *query = OwnerFaceBaseQuery(service, account);
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,
                                    (__bridge CFDictionaryRef)@{(id)kSecValueData: data});
    if (status == errSecItemNotFound) {
        NSMutableDictionary *newItem = [query mutableCopy];
        newItem[(id)kSecValueData] = data;
        newItem[(id)kSecAttrAccessible] = (id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
        status = SecItemAdd((__bridge CFDictionaryRef)newItem, NULL);
    }
    if (status != errSecSuccess) {
        if (error) *error = OwnerFaceKeychainError(status, @"保存本人特征");
        return NO;
    }
    return YES;
}

- (BOOL)deleteDataForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)OwnerFaceBaseQuery(service, account));
    if (status == errSecSuccess || status == errSecItemNotFound) return YES;
    if (error) *error = OwnerFaceKeychainError(status, @"删除本人特征");
    return NO;
}

@end

@interface OwnerFaceProfileStore ()
@property(nonatomic, strong) id<OwnerFaceKeychainClient> keychainClient;
@end

@implementation OwnerFaceProfileStore

- (instancetype)initWithKeychainClient:(id<OwnerFaceKeychainClient>)keychainClient {
    self = [super init];
    if (self) _keychainClient = keychainClient;
    return self;
}

- (OwnerFaceProfile *)loadProfileAndReturnError:(NSError **)error {
    NSData *data = [self.keychainClient dataForService:OwnerFaceProfileService
                                               account:OwnerFaceProfileAccount
                                                 error:error];
    if (!data) return nil;
    return [OwnerFaceProfile profileFromData:data error:error];
}

- (BOOL)saveProfile:(OwnerFaceProfile *)profile error:(NSError **)error {
    NSData *data = [profile encodedDataAndReturnError:error];
    if (!data) return NO;
    // SecItemUpdate replaces the value atomically; a failure leaves the previous value intact.
    return [self.keychainClient setData:data service:OwnerFaceProfileService
                                account:OwnerFaceProfileAccount error:error];
}

- (BOOL)deleteProfileAndReturnError:(NSError **)error {
    return [self.keychainClient deleteDataForService:OwnerFaceProfileService
                                             account:OwnerFaceProfileAccount error:error];
}

@end

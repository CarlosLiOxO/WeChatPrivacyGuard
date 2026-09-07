#import <Foundation/Foundation.h>
#import "OwnerFaceProfile.h"

NS_ASSUME_NONNULL_BEGIN

@protocol OwnerFaceKeychainClient <NSObject>
- (nullable NSData *)dataForService:(NSString *)service account:(NSString *)account error:(NSError **)error;
- (BOOL)setData:(NSData *)data service:(NSString *)service account:(NSString *)account error:(NSError **)error;
- (BOOL)deleteDataForService:(NSString *)service account:(NSString *)account error:(NSError **)error;
@end

@interface SystemOwnerFaceKeychainClient : NSObject <OwnerFaceKeychainClient>
@end

@interface OwnerFaceProfileStore : NSObject

- (instancetype)initWithKeychainClient:(id<OwnerFaceKeychainClient>)keychainClient;
- (nullable OwnerFaceProfile *)loadProfileAndReturnError:(NSError **)error;
- (BOOL)saveProfile:(OwnerFaceProfile *)profile error:(NSError **)error;
- (BOOL)deleteProfileAndReturnError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>
#import "ProtectedApplication.h"

NS_ASSUME_NONNULL_BEGIN

@interface ProtectedApplicationStore : NSObject

@property(nonatomic, strong, readonly) NSUserDefaults *defaults;

- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults;
- (nullable ProtectedApplication *)selectedApplication;
- (void)saveApplication:(ProtectedApplication *)application;
- (void)clear;

@end
NS_ASSUME_NONNULL_END

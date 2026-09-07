#import <Foundation/Foundation.h>
#import "ProtectedApplication.h"

NS_ASSUME_NONNULL_BEGIN

@interface ApplicationCatalog : NSObject

- (instancetype)init;
- (instancetype)initWithSearchURLs:(NSArray<NSURL *> *)searchURLs
          excludedBundleIdentifiers:(NSSet<NSString *> *)excludedBundleIdentifiers;
- (NSArray<ProtectedApplication *> *)scanApplications;

@end
NS_ASSUME_NONNULL_END

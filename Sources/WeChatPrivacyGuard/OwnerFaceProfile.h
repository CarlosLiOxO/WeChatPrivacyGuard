#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const OwnerFaceProfileErrorDomain;

@interface OwnerFaceProfile : NSObject

@property(nonatomic, readonly) NSInteger formatVersion;
@property(nonatomic, copy, readonly) NSString *modelIdentifier;
@property(nonatomic, readonly) NSUInteger embeddingDimension;
@property(nonatomic, copy, readonly) NSArray<NSArray<NSNumber *> *> *ownerTemplates;
@property(nonatomic, strong, readonly) NSDate *createdAt;

- (nullable instancetype)initWithModelIdentifier:(NSString *)modelIdentifier
                                   ownerTemplates:(NSArray<NSArray<NSNumber *> *> *)ownerTemplates;
- (nullable NSData *)encodedDataAndReturnError:(NSError **)error;
+ (nullable instancetype)profileFromData:(NSData *)data error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

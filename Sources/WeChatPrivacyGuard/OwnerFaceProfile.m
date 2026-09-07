#import "OwnerFaceProfile.h"
#import <math.h>

NSString *const OwnerFaceProfileErrorDomain = @"com.carlosli.WeChatPrivacyGuard.OwnerFaceProfile";
static const NSInteger CurrentOwnerFaceProfileFormatVersion = 1;

static NSError *OwnerFaceProfileError(NSString *description) {
    return [NSError errorWithDomain:OwnerFaceProfileErrorDomain code:1
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

static BOOL OwnerFaceTemplatesAreValid(NSArray<NSArray<NSNumber *> *> *templates,
                                       NSUInteger *dimension) {
    if (templates.count == 0 || templates.count > 32) return NO;
    NSUInteger expectedDimension = templates.firstObject.count;
    if (expectedDimension == 0 || expectedDimension > 4096) return NO;
    for (NSArray<NSNumber *> *embedding in templates) {
        if (![embedding isKindOfClass:NSArray.class] || embedding.count != expectedDimension) return NO;
        double normSquared = 0;
        for (NSNumber *number in embedding) {
            if (![number isKindOfClass:NSNumber.class] || !isfinite(number.doubleValue)) return NO;
            normSquared += number.doubleValue * number.doubleValue;
        }
        if (!isfinite(normSquared) || normSquared < 1e-12) return NO;
    }
    if (dimension) *dimension = expectedDimension;
    return YES;
}

@interface OwnerFaceProfile ()
@property(nonatomic, readwrite) NSInteger formatVersion;
@property(nonatomic, copy, readwrite) NSString *modelIdentifier;
@property(nonatomic, readwrite) NSUInteger embeddingDimension;
@property(nonatomic, copy, readwrite) NSArray<NSArray<NSNumber *> *> *ownerTemplates;
@property(nonatomic, strong, readwrite) NSDate *createdAt;
@end

@implementation OwnerFaceProfile

- (instancetype)initWithModelIdentifier:(NSString *)modelIdentifier
                           ownerTemplates:(NSArray<NSArray<NSNumber *> *> *)ownerTemplates {
    NSUInteger dimension = 0;
    if (modelIdentifier.length == 0 || !OwnerFaceTemplatesAreValid(ownerTemplates, &dimension)) return nil;
    self = [super init];
    if (self) {
        _formatVersion = CurrentOwnerFaceProfileFormatVersion;
        _modelIdentifier = [modelIdentifier copy];
        _embeddingDimension = dimension;
        _ownerTemplates = [ownerTemplates copy];
        _createdAt = [NSDate date];
    }
    return self;
}

- (NSData *)encodedDataAndReturnError:(NSError **)error {
    NSUInteger dimension = 0;
    if (self.formatVersion != CurrentOwnerFaceProfileFormatVersion ||
        self.modelIdentifier.length == 0 ||
        !OwnerFaceTemplatesAreValid(self.ownerTemplates, &dimension) ||
        dimension != self.embeddingDimension) {
        if (error) *error = OwnerFaceProfileError(@"本人特征模板无效");
        return nil;
    }
    NSDictionary *propertyList = @{
        @"formatVersion": @(self.formatVersion),
        @"modelIdentifier": self.modelIdentifier,
        @"embeddingDimension": @(self.embeddingDimension),
        @"ownerTemplates": self.ownerTemplates,
        @"createdAt": self.createdAt,
    };
    return [NSPropertyListSerialization dataWithPropertyList:propertyList
                                                       format:NSPropertyListBinaryFormat_v1_0
                                                      options:0
                                                        error:error];
}

+ (instancetype)profileFromData:(NSData *)data error:(NSError **)error {
    id decoded = [NSPropertyListSerialization propertyListWithData:data
                                                           options:NSPropertyListImmutable
                                                            format:nil
                                                             error:error];
    if (![decoded isKindOfClass:NSDictionary.class]) {
        if (error && !*error) *error = OwnerFaceProfileError(@"本人特征数据格式错误");
        return nil;
    }
    NSDictionary *dictionary = decoded;
    NSNumber *formatVersion = dictionary[@"formatVersion"];
    NSString *modelIdentifier = dictionary[@"modelIdentifier"];
    NSNumber *embeddingDimension = dictionary[@"embeddingDimension"];
    NSArray *ownerTemplates = dictionary[@"ownerTemplates"];
    NSDate *createdAt = dictionary[@"createdAt"];
    if (![formatVersion isKindOfClass:NSNumber.class] ||
        formatVersion.integerValue != CurrentOwnerFaceProfileFormatVersion ||
        ![modelIdentifier isKindOfClass:NSString.class] ||
        ![embeddingDimension isKindOfClass:NSNumber.class] ||
        ![ownerTemplates isKindOfClass:NSArray.class] ||
        ![createdAt isKindOfClass:NSDate.class]) {
        if (error) *error = OwnerFaceProfileError(@"本人特征版本或字段无效");
        return nil;
    }

    OwnerFaceProfile *profile = [[OwnerFaceProfile alloc]
        initWithModelIdentifier:modelIdentifier ownerTemplates:ownerTemplates];
    if (!profile || profile.embeddingDimension != embeddingDimension.unsignedIntegerValue) {
        if (error) *error = OwnerFaceProfileError(@"本人特征向量无效");
        return nil;
    }
    profile.createdAt = createdAt;
    return profile;
}

@end

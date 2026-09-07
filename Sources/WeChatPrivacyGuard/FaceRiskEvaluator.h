#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ProtectionDistance) {
    ProtectionDistanceNear = 0,
    ProtectionDistanceStandard = 1,
    ProtectionDistanceFar = 2,
};

typedef NS_ENUM(NSInteger, FaceRiskState) {
    FaceRiskStateNone = 0,
    FaceRiskStateBorderline = 1,
    FaceRiskStatePresent = 2,
};

FOUNDATION_EXPORT CGFloat FaceHeightThresholdForProtectionDistance(ProtectionDistance distance);

@interface FaceRiskObservation : NSObject

@property(nonatomic, readonly) CGRect boundingBox;
@property(nonatomic, strong, readonly, nullable) NSNumber *yaw;

- (instancetype)initWithBoundingBox:(CGRect)boundingBox yaw:(nullable NSNumber *)yaw;

@end

@interface FaceRiskEvaluator : NSObject

@property(nonatomic) ProtectionDistance protectionDistance;

- (instancetype)initWithProtectionDistance:(ProtectionDistance)protectionDistance;
- (FaceRiskState)evaluateObservations:(NSArray<FaceRiskObservation *> *)observations;

@end

NS_ASSUME_NONNULL_END

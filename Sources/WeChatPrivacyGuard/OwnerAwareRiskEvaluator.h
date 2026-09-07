#import <Foundation/Foundation.h>
#import "FaceRiskEvaluator.h"
#import "OwnerFaceMatcher.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT BOOL FaceBoundingBoxSupportsReliableIdentityCrop(CGRect boundingBox);
FOUNDATION_EXPORT BOOL FacePoseCanViewScreen(NSNumber * _Nullable yaw);
FOUNDATION_EXPORT BOOL OwnerAwareFaceCanTriggerPrivacy(CGRect boundingBox,
                                                       NSNumber * _Nullable yaw);

@interface OwnerAwareFaceObservation : NSObject

@property(nonatomic, readonly) CGRect boundingBox;
@property(nonatomic, strong, readonly, nullable) NSNumber *yaw;
@property(nonatomic, readonly) FaceIdentityResult identityResult;

- (instancetype)initWithBoundingBox:(CGRect)boundingBox
                                yaw:(nullable NSNumber *)yaw
                     identityResult:(FaceIdentityResult)identityResult;

@end

@interface OwnerAwareRiskEvaluator : NSObject

@property(nonatomic) ProtectionDistance protectionDistance;

- (instancetype)initWithProtectionDistance:(ProtectionDistance)protectionDistance;
- (FaceRiskState)evaluateObservations:(NSArray<OwnerAwareFaceObservation *> *)observations;

@end

NS_ASSUME_NONNULL_END

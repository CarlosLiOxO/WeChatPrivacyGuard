#import <Foundation/Foundation.h>
#import "FaceAnalysisFrame.h"
#import "FaceRiskEvaluator.h"
#import "OwnerFaceProfile.h"

NS_ASSUME_NONNULL_BEGIN

@interface OwnerAwareFaceCoordinator : NSObject

@property(nonatomic) ProtectionDistance protectionDistance;

- (nullable instancetype)initWithProfile:(OwnerFaceProfile *)profile
                                 modelURL:(NSURL *)modelURL
                       protectionDistance:(ProtectionDistance)protectionDistance
                                    error:(NSError **)error;
- (FaceRiskState)evaluateFrame:(FaceAnalysisFrame *)frame;
- (void)reset;

@end

NS_ASSUME_NONNULL_END

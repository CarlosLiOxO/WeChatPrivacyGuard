#import <Foundation/Foundation.h>
#import "FaceRiskEvaluator.h"

NS_ASSUME_NONNULL_BEGIN

@interface PresenceDebouncer : NSObject

- (instancetype)initWithRequiredDuration:(NSTimeInterval)requiredDuration;
- (BOOL)recordRiskState:(FaceRiskState)riskState atTime:(NSTimeInterval)time;
- (void)reset;

@end

NS_ASSUME_NONNULL_END

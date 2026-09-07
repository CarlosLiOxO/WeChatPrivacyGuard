#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FaceJudgementMode) {
    FaceJudgementModeSecondPerson = 0,
    FaceJudgementModeUnknownPerson = 1,
};

@interface FaceJudgementModeStore : NSObject

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults;
- (FaceJudgementMode)faceJudgementMode;
- (void)saveFaceJudgementMode:(FaceJudgementMode)mode;

@end

NS_ASSUME_NONNULL_END

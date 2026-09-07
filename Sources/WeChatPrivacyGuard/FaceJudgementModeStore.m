#import "FaceJudgementModeStore.h"

static NSString *const FaceJudgementModeDefaultsKey = @"faceJudgementMode";

@interface FaceJudgementModeStore ()
@property(nonatomic, strong) NSUserDefaults *userDefaults;
@end

@implementation FaceJudgementModeStore

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
    self = [super init];
    if (self) _userDefaults = userDefaults;
    return self;
}

- (FaceJudgementMode)faceJudgementMode {
    NSNumber *stored = [self.userDefaults objectForKey:FaceJudgementModeDefaultsKey];
    if (!stored) return FaceJudgementModeSecondPerson;
    NSInteger value = stored.integerValue;
    if (value != FaceJudgementModeSecondPerson && value != FaceJudgementModeUnknownPerson) {
        return FaceJudgementModeSecondPerson;
    }
    return value;
}

- (void)saveFaceJudgementMode:(FaceJudgementMode)mode {
    FaceJudgementMode validated = mode == FaceJudgementModeUnknownPerson
        ? FaceJudgementModeUnknownPerson : FaceJudgementModeSecondPerson;
    [self.userDefaults setInteger:validated forKey:FaceJudgementModeDefaultsKey];
}

@end

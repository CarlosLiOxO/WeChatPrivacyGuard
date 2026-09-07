#import <Foundation/Foundation.h>
#import "FaceRiskEvaluator.h"
#import "ProtectionModeStore.h"
#import "WindowPrivacyOverlayController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ProtectionActionState) {
    ProtectionActionStateIdle = 0,
    ProtectionActionStateOverlayActive = 1,
    ProtectionActionStateWaitingForRecovery = 2,
    ProtectionActionStateHidden = 3,
};

@interface ProtectionActionCoordinator : NSObject

@property(nonatomic) ProtectionMode protectionMode;
@property(nonatomic, readonly) ProtectionActionState state;
@property(nonatomic, readonly) BOOL canClearOverlay;
@property(nonatomic, copy, nullable) void (^stateDidChange)(ProtectionActionState state,
                                                               NSString * _Nullable statusMessage,
                                                               BOOL canClearOverlay);

- (instancetype)initWithOverlayController:(id<PrivacyOverlayManaging>)overlayController
                               hideHandler:(BOOL (^)(NSString *bundleIdentifier))hideHandler;
- (void)handleRiskState:(FaceRiskState)riskState
             didTrigger:(BOOL)didTrigger
                  atTime:(NSTimeInterval)time
       bundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers;
- (void)testProtectionAtTime:(NSTimeInterval)time
            bundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers;
- (void)advanceToTime:(NSTimeInterval)time;
- (void)updateBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers;
- (void)clearOverlay;
- (void)stop;

@end
NS_ASSUME_NONNULL_END

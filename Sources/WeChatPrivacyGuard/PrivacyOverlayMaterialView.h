#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PrivacyOverlayLayoutMode) {
    PrivacyOverlayLayoutModeCompact = 0,
    PrivacyOverlayLayoutModeRegular = 1,
};

FOUNDATION_EXPORT PrivacyOverlayLayoutMode PrivacyOverlayLayoutModeForSize(NSSize size);
FOUNDATION_EXPORT BOOL PrivacyOverlayUsesOpaqueFallback(BOOL reduceTransparency,
                                                        BOOL visualEffectAvailable);

@interface PrivacyOverlayMaterialView : NSView
@property(nonatomic, readonly) BOOL usingOpaqueFallback;
- (void)refreshAccessibilityAppearance;
@end

NS_ASSUME_NONNULL_END

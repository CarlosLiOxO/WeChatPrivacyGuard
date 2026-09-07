#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PrivacyOverlayLayoutMode) {
    PrivacyOverlayLayoutModeCompact = 0,
    PrivacyOverlayLayoutModeRegular = 1,
};

typedef NS_ENUM(NSInteger, PrivacyOverlayAppearanceStyle) {
    PrivacyOverlayAppearanceStyleLight = 0,
    PrivacyOverlayAppearanceStyleDark = 1,
};

FOUNDATION_EXPORT PrivacyOverlayLayoutMode PrivacyOverlayLayoutModeForSize(NSSize size);
FOUNDATION_EXPORT BOOL PrivacyOverlayUsesOpaqueFallback(BOOL reduceTransparency,
                                                        BOOL visualEffectAvailable);
FOUNDATION_EXPORT PrivacyOverlayAppearanceStyle PrivacyOverlayAppearanceStyleForAppearance(
    NSAppearance * _Nullable appearance);
FOUNDATION_EXPORT BOOL PrivacyOverlayShowsTemporaryRevealButton(NSSize size);
FOUNDATION_EXPORT BOOL PrivacyOverlayRevealButtonAcceptsFirstMouse(void);

@interface PrivacyOverlayMaterialView : NSView
@property(nonatomic, readonly) BOOL usingOpaqueFallback;
@property(nonatomic, copy, nullable) void (^temporaryRevealHandler)(void);
- (void)refreshAccessibilityAppearance;
@end

NS_ASSUME_NONNULL_END

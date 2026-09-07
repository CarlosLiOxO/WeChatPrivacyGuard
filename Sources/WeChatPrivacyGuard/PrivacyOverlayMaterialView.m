#import "PrivacyOverlayMaterialView.h"

PrivacyOverlayLayoutMode PrivacyOverlayLayoutModeForSize(NSSize size) {
    return size.width >= 300 && size.height >= 180
        ? PrivacyOverlayLayoutModeRegular : PrivacyOverlayLayoutModeCompact;
}

BOOL PrivacyOverlayUsesOpaqueFallback(BOOL reduceTransparency, BOOL visualEffectAvailable) {
    return reduceTransparency || !visualEffectAvailable;
}

@interface PrivacyOverlayDecorationView : NSView
@property(nonatomic) BOOL opaqueFallback;
@end


@implementation PrivacyOverlayDecorationView

- (BOOL)isOpaque {
    return self.opaqueFallback;
}

- (void)setOpaqueFallback:(BOOL)opaqueFallback {
    _opaqueFallback = opaqueFallback;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    CGFloat fogAlpha = self.opaqueFallback ? 1.0 : 0.88;
    [[NSColor colorWithSRGBRed:0.906 green:0.937 blue:0.953 alpha:fogAlpha] setFill];
    NSRectFill(bounds);

    [self drawGlowInRect:NSMakeRect(NSMinX(bounds) - NSWidth(bounds) * 0.18,
                                    NSMaxY(bounds) - NSHeight(bounds) * 0.63,
                                    NSWidth(bounds) * 0.72,
                                    NSHeight(bounds) * 0.78)
                   color:[NSColor colorWithSRGBRed:0.55 green:0.76 blue:0.83 alpha:0.48]];
    [self drawGlowInRect:NSMakeRect(NSMaxX(bounds) - NSWidth(bounds) * 0.55,
                                    NSMinY(bounds) - NSHeight(bounds) * 0.20,
                                    NSWidth(bounds) * 0.70,
                                    NSHeight(bounds) * 0.75)
                   color:[NSColor colorWithSRGBRed:0.53 green:0.76 blue:0.68 alpha:0.42]];

    if (PrivacyOverlayLayoutModeForSize(bounds.size) == PrivacyOverlayLayoutModeCompact) {
        [self drawLensAtPoint:NSMakePoint(NSMidX(bounds), NSMidY(bounds)) scale:0.72];
        return;
    }

    CGFloat cardWidth = MIN(264, NSWidth(bounds) - 40);
    NSRect cardRect = NSMakeRect(NSMidX(bounds) - cardWidth / 2,
                                 NSMidY(bounds) - 66,
                                 cardWidth, 132);
    [NSGraphicsContext saveGraphicsState];
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [NSColor colorWithSRGBRed:0.20 green:0.31 blue:0.37 alpha:0.17];
    shadow.shadowBlurRadius = 24;
    shadow.shadowOffset = NSMakeSize(0, -9);
    [shadow set];
    NSBezierPath *card = [NSBezierPath bezierPathWithRoundedRect:cardRect xRadius:24 yRadius:24];
    [[NSColor colorWithSRGBRed:1 green:1 blue:1 alpha:0.62] setFill];
    [card fill];
    [NSGraphicsContext restoreGraphicsState];

    [[NSColor colorWithSRGBRed:1 green:1 blue:1 alpha:0.86] setStroke];
    card.lineWidth = 1;
    [card stroke];

    NSPoint lensCenter = NSMakePoint(NSMidX(cardRect), NSMaxY(cardRect) - 44);
    [self drawLensAtPoint:lensCenter scale:0.76];

    NSDictionary *titleAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor colorWithSRGBRed:0.15 green:0.21 blue:0.25 alpha:1],
    };
    NSString *title = @"窗口已保护";
    NSSize titleSize = [title sizeWithAttributes:titleAttributes];
    [title drawAtPoint:NSMakePoint(NSMidX(cardRect) - titleSize.width / 2, NSMinY(cardRect) + 35)
         withAttributes:titleAttributes];

    NSDictionary *subtitleAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor colorWithSRGBRed:0.37 green:0.46 blue:0.51 alpha:0.82],
    };
    NSString *subtitle = @"风险解除后自动恢复";
    NSSize subtitleSize = [subtitle sizeWithAttributes:subtitleAttributes];
    [subtitle drawAtPoint:NSMakePoint(NSMidX(cardRect) - subtitleSize.width / 2, NSMinY(cardRect) + 16)
            withAttributes:subtitleAttributes];
}

- (void)drawGlowInRect:(NSRect)rect color:(NSColor *)color {
    NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:rect];
    NSGradient *gradient = [[NSGradient alloc]
        initWithStartingColor:color
                  endingColor:[color colorWithAlphaComponent:0]];
    [gradient drawInBezierPath:path relativeCenterPosition:NSZeroPoint];
}

- (void)drawLensAtPoint:(NSPoint)center scale:(CGFloat)scale {
    CGFloat halfWidth = 35 * scale;
    CGFloat halfHeight = 22 * scale;
    NSBezierPath *eye = [NSBezierPath bezierPath];
    [eye moveToPoint:NSMakePoint(center.x - halfWidth, center.y)];
    [eye curveToPoint:NSMakePoint(center.x + halfWidth, center.y)
        controlPoint1:NSMakePoint(center.x - halfWidth * 0.52, center.y + halfHeight)
        controlPoint2:NSMakePoint(center.x + halfWidth * 0.52, center.y + halfHeight)];
    [eye curveToPoint:NSMakePoint(center.x - halfWidth, center.y)
        controlPoint1:NSMakePoint(center.x + halfWidth * 0.52, center.y - halfHeight)
        controlPoint2:NSMakePoint(center.x - halfWidth * 0.52, center.y - halfHeight)];
    [[NSColor colorWithSRGBRed:0.29 green:0.56 blue:0.64 alpha:1] setStroke];
    eye.lineWidth = 2.4 * scale;
    [eye stroke];

    CGFloat irisRadius = 9 * scale;
    [[NSColor colorWithSRGBRed:0.39 green:0.68 blue:0.61 alpha:1] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - irisRadius,
                                                        center.y - irisRadius,
                                                        irisRadius * 2,
                                                        irisRadius * 2)] fill];
    CGFloat pupilRadius = 3.5 * scale;
    [[NSColor colorWithSRGBRed:0.10 green:0.19 blue:0.23 alpha:1] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - pupilRadius,
                                                        center.y - pupilRadius,
                                                        pupilRadius * 2,
                                                        pupilRadius * 2)] fill];
}

@end


@interface PrivacyOverlayMaterialView ()
@property(nonatomic, strong, nullable) NSVisualEffectView *visualEffectView;
@property(nonatomic, strong) PrivacyOverlayDecorationView *decorationView;
@property(nonatomic, readwrite) BOOL usingOpaqueFallback;
@end

@implementation PrivacyOverlayMaterialView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.autoresizesSubviews = YES;
        @try {
            _visualEffectView = [[NSVisualEffectView alloc] initWithFrame:self.bounds];
            _visualEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
            _visualEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
            _visualEffectView.material = NSVisualEffectMaterialUnderWindowBackground;
            _visualEffectView.state = NSVisualEffectStateActive;
            _visualEffectView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
            [self addSubview:_visualEffectView];
        } @catch (NSException *exception) {
            _visualEffectView = nil;
        }

        _decorationView = [[PrivacyOverlayDecorationView alloc] initWithFrame:self.bounds];
        _decorationView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self addSubview:_decorationView];
        self.accessibilityLabel = @"隐私保护遮罩";
        [self refreshAccessibilityAppearance];

        [NSWorkspace.sharedWorkspace.notificationCenter
            addObserver:self
               selector:@selector(accessibilityDisplayOptionsDidChange:)
                   name:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification
                 object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}

- (BOOL)isOpaque {
    return self.usingOpaqueFallback;
}

- (void)refreshAccessibilityAppearance {
    BOOL reduceTransparency = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency;
    self.usingOpaqueFallback = PrivacyOverlayUsesOpaqueFallback(
        reduceTransparency, self.visualEffectView != nil);
    self.visualEffectView.hidden = self.usingOpaqueFallback;
    self.decorationView.opaqueFallback = self.usingOpaqueFallback;
    [self setNeedsDisplay:YES];
}

- (void)accessibilityDisplayOptionsDidChange:(NSNotification *)notification {
    [self refreshAccessibilityAppearance];
}

@end

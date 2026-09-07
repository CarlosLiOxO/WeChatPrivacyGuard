#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProtectedWindowDescriptor : NSObject
@property(nonatomic, readonly) CGWindowID windowNumber;
@property(nonatomic, readonly) pid_t processIdentifier;
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@property(nonatomic, readonly) CGRect quartzBounds;
- (instancetype)initWithWindowNumber:(CGWindowID)windowNumber
                   processIdentifier:(pid_t)processIdentifier
                    bundleIdentifier:(NSString *)bundleIdentifier
                        quartzBounds:(CGRect)quartzBounds;
@end

@interface WindowMetadataFilter : NSObject
+ (NSArray<ProtectedWindowDescriptor *> *)descriptorsFromWindowInfo:(NSArray<NSDictionary *> *)windowInfo
                                                 processIdentifiers:(NSDictionary<NSNumber *, NSString *> *)processIdentifiers;
@end

@protocol PrivacyOverlayManaging <NSObject>
@property(nonatomic, readonly) NSUInteger overlayCount;
@property(nonatomic, copy, nullable) void (^fallbackHandler)(NSString *bundleIdentifier);
- (void)activateForBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers;
- (void)updateBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers;
- (void)deactivateAnimated:(BOOL)animated;
@end

@interface WindowPrivacyOverlayController : NSObject <PrivacyOverlayManaging>

@property(nonatomic, readonly) NSUInteger overlayCount;
@property(nonatomic, copy, nullable) void (^fallbackHandler)(NSString *bundleIdentifier);
@property(nonatomic, copy, nullable) void (^overlayCountDidChange)(NSUInteger overlayCount);

- (void)activateForBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers;
- (void)updateBundleIdentifiers:(NSSet<NSString *> *)bundleIdentifiers;
- (void)deactivateAnimated:(BOOL)animated;
- (void)refreshNow;
- (void)temporarilyRevealBundleIdentifier:(NSString *)bundleIdentifier;
- (BOOL)isBundleIdentifierTemporarilyRevealed:(NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END

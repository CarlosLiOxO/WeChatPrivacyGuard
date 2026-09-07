#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import "FaceAnalysisFrame.h"
#import "OwnerFaceProfile.h"

NS_ASSUME_NONNULL_BEGIN

@interface OwnerFaceEnrollmentWindowController : NSWindowController

@property(nonatomic, copy, nullable) void (^completionHandler)(OwnerFaceProfile *profile);
@property(nonatomic, copy, nullable) void (^cancellationHandler)(void);
@property(nonatomic, strong, nullable) AVCaptureVideoPreviewLayer *cameraPreviewLayer;

- (nullable instancetype)initWithModelURL:(NSURL *)modelURL error:(NSError **)error;
- (void)beginEnrollment;
- (void)consumeFrame:(FaceAnalysisFrame *)frame;

@end

NS_ASSUME_NONNULL_END

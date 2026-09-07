#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import "FaceRiskEvaluator.h"
#import "FaceAnalysisFrame.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT BOOL CameraEnrollmentPreviewShouldMirror(void);
FOUNDATION_EXPORT NSTimeInterval CameraAnalysisInterval(BOOL identityAnalysisEnabled);
FOUNDATION_EXPORT BOOL CameraShouldRequestIdentityQuality(BOOL identityAnalysisEnabled,
                                                          NSUInteger detectedFaceCount);

typedef NS_ENUM(NSInteger, CameraServiceState) {
    CameraServiceStateStopped,
    CameraServiceStateRequestingPermission,
    CameraServiceStateRunning,
    CameraServiceStatePermissionDenied,
    CameraServiceStateUnavailable,
    CameraServiceStateFailed,
};

@class CameraService;

@protocol CameraServiceDelegate <NSObject>
- (void)cameraService:(CameraService *)service
       didChangeState:(CameraServiceState)state
              message:(nullable NSString *)message;
- (void)cameraService:(CameraService *)service
 didDetectObservations:(NSArray<FaceRiskObservation *> *)observations;
@optional
- (void)cameraService:(CameraService *)service didAnalyzeFrame:(FaceAnalysisFrame *)frame;
@end

@interface CameraService : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic, weak, nullable) id<CameraServiceDelegate> delegate;
@property(atomic) BOOL identityAnalysisEnabled;

- (void)start;
- (void)stop;
- (AVCaptureVideoPreviewLayer *)makeEnrollmentPreviewLayer;

@end

NS_ASSUME_NONNULL_END

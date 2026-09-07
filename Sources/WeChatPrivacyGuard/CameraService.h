#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import "FaceRiskEvaluator.h"

NS_ASSUME_NONNULL_BEGIN

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
@end

@interface CameraService : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic, weak, nullable) id<CameraServiceDelegate> delegate;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END

#import "CameraService.h"
#import <Vision/Vision.h>

BOOL CameraEnrollmentPreviewShouldMirror(void) {
    return YES;
}

NSTimeInterval CameraAnalysisInterval(BOOL identityAnalysisEnabled) {
    // Capture-quality analysis measured 1.271x the cost of rectangle detection on the
    // development Mac (4.433 ms vs 3.487 ms). At 6.25 Hz its Vision compute budget is
    // about 20% below the previous 10 Hz rectangle-only identity pipeline.
    return identityAnalysisEnabled ? 0.16 : 0.16;
}

BOOL CameraShouldRequestIdentityQuality(BOOL identityAnalysisEnabled,
                                        NSUInteger detectedFaceCount) {
    return identityAnalysisEnabled && detectedFaceCount == 1;
}

@interface CameraService ()
@property(nonatomic, strong) AVCaptureSession *session;
@property(nonatomic) dispatch_queue_t sessionQueue;
@property(nonatomic) dispatch_queue_t analysisQueue;
@property(nonatomic, strong) VNDetectFaceRectanglesRequest *faceRequest;
@property(nonatomic, strong) VNDetectFaceCaptureQualityRequest *faceQualityRequest;
@property(nonatomic) NSTimeInterval lastAnalysisTime;
@property(atomic) BOOL wantsToRun;
@property(atomic) BOOL identityAnalysisEnabledStorage;
@property(nonatomic) BOOL configured;
@property(nonatomic, strong) NSHashTable<AVCaptureVideoPreviewLayer *> *previewLayers;
@end

@implementation CameraService

- (instancetype)init {
    self = [super init];
    if (self) {
        _session = [[AVCaptureSession alloc] init];
        _sessionQueue = dispatch_queue_create("com.carlosli.WeChatPrivacyGuard.camera-session", DISPATCH_QUEUE_SERIAL);
        _analysisQueue = dispatch_queue_create("com.carlosli.WeChatPrivacyGuard.face-analysis", DISPATCH_QUEUE_SERIAL);
        _faceRequest = [[VNDetectFaceRectanglesRequest alloc] init];
        _faceRequest.revision = VNDetectFaceRectanglesRequestRevision3;
        _faceQualityRequest = [[VNDetectFaceCaptureQualityRequest alloc] init];
        _faceQualityRequest.revision = VNDetectFaceCaptureQualityRequestRevision2;
        _previewLayers = [NSHashTable weakObjectsHashTable];

        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(sessionWasInterrupted:)
                      name:AVCaptureSessionWasInterruptedNotification object:_session];
        [center addObserver:self selector:@selector(sessionInterruptionEnded:)
                      name:AVCaptureSessionInterruptionEndedNotification object:_session];
        [center addObserver:self selector:@selector(sessionRuntimeError:)
                      name:AVCaptureSessionRuntimeErrorNotification object:_session];
    }
    return self;
}

- (AVCaptureVideoPreviewLayer *)makeEnrollmentPreviewLayer {
    AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    [self.previewLayers addObject:layer];
    [self configureEnrollmentPreviewLayer:layer];
    return layer;
}

- (void)configureEnrollmentPreviewLayer:(AVCaptureVideoPreviewLayer *)layer {
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    AVCaptureConnection *connection = layer.connection;
    connection.automaticallyAdjustsVideoMirroring = NO;
    if (connection.isVideoMirroringSupported) {
        connection.videoMirrored = CameraEnrollmentPreviewShouldMirror();
    }
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)start {
    self.wantsToRun = YES;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            [self configureAndStart];
            break;
        case AVAuthorizationStatusNotDetermined: {
            [self publishState:CameraServiceStateRequestingPermission message:nil];
            __weak typeof(self) weakSelf = self;
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                if (granted && self.wantsToRun) {
                    [self configureAndStart];
                } else {
                    [self publishState:CameraServiceStatePermissionDenied message:nil];
                }
            }];
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            [self publishState:CameraServiceStatePermissionDenied message:nil];
            break;
    }
}

- (void)stop {
    self.wantsToRun = NO;
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.session.isRunning) {
            [self.session stopRunning];
        }
        [self publishState:CameraServiceStateStopped message:nil];
    });
}

- (void)setIdentityAnalysisEnabled:(BOOL)identityAnalysisEnabled {
    if (self.identityAnalysisEnabledStorage == identityAnalysisEnabled) return;
    self.identityAnalysisEnabledStorage = identityAnalysisEnabled;
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.configured) return;
        NSString *preset = identityAnalysisEnabled ? AVCaptureSessionPreset640x480 : AVCaptureSessionPresetLow;
        if (![self.session canSetSessionPreset:preset]) return;
        [self.session beginConfiguration];
        self.session.sessionPreset = preset;
        [self.session commitConfiguration];
    });
}

- (BOOL)identityAnalysisEnabled {
    return self.identityAnalysisEnabledStorage;
}

- (void)configureAndStart {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.wantsToRun) return;

        NSError *error = nil;
        if (!self.configured && ![self configureSession:&error]) {
            [self publishState:CameraServiceStateFailed message:error.localizedDescription];
            return;
        }
        if (!self.session.isRunning) {
            [self.session startRunning];
        }
        if (self.session.isRunning) {
            [self publishState:CameraServiceStateRunning message:nil];
        } else {
            [self publishState:CameraServiceStateFailed message:@"摄像头未能启动"];
        }
    });
}

- (BOOL)configureSession:(NSError **)error {
    [self.session beginConfiguration];
    NSString *preset = self.identityAnalysisEnabled ? AVCaptureSessionPreset640x480 : AVCaptureSessionPresetLow;
    self.session.sessionPreset = [self.session canSetSessionPreset:preset] ? preset : AVCaptureSessionPresetLow;

    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                 mediaType:AVMediaTypeVideo
                                                                  position:AVCaptureDevicePositionFront];
    if (!camera) {
        camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    if (!camera) {
        if (error) *error = [self errorWithDescription:@"没有找到可用摄像头"];
        [self.session commitConfiguration];
        return NO;
    }

    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:error];
    if (!input || ![self.session canAddInput:input]) {
        if (error && !*error) *error = [self errorWithDescription:@"无法连接摄像头输入"];
        [self.session commitConfiguration];
        return NO;
    }
    [self.session addInput:input];

    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;
    output.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    [output setSampleBufferDelegate:self queue:self.analysisQueue];
    if (![self.session canAddOutput:output]) {
        if (error) *error = [self errorWithDescription:@"无法创建摄像头输出"];
        [self.session commitConfiguration];
        return NO;
    }
    [self.session addOutput:output];
    [self.session commitConfiguration];
    dispatch_async(dispatch_get_main_queue(), ^{
        for (AVCaptureVideoPreviewLayer *layer in self.previewLayers) {
            [self configureEnrollmentPreviewLayer:layer];
        }
    });
    self.configured = YES;
    return YES;
}

- (void)captureOutput:(AVCaptureOutput *)output
 didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
        fromConnection:(AVCaptureConnection *)connection {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    NSTimeInterval interval = CameraAnalysisInterval(self.identityAnalysisEnabled);
    if (now - self.lastAnalysisTime < interval) return;
    self.lastAnalysisTime = now;

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) return;

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];
    NSError *error = nil;
    if (![handler performRequests:@[self.faceRequest] error:&error]) {
        [self publishState:CameraServiceStateFailed
                   message:[NSString stringWithFormat:@"人脸检测失败：%@", error.localizedDescription]];
        return;
    }

    NSMutableArray<FaceRiskObservation *> *observations = [NSMutableArray array];
    NSArray<VNFaceObservation *> *faces = self.faceRequest.results;
    if (CameraShouldRequestIdentityQuality(self.identityAnalysisEnabled, faces.count)) {
        self.faceQualityRequest.inputFaceObservations = faces;
        NSError *qualityError = nil;
        if ([handler performRequests:@[self.faceQualityRequest] error:&qualityError]) {
            faces = self.faceQualityRequest.results;
        }
        self.faceQualityRequest.inputFaceObservations = nil;
    }
    for (VNFaceObservation *face in faces) {
        [observations addObject:[[FaceRiskObservation alloc]
            initWithBoundingBox:face.boundingBox
            yaw:face.yaw
            captureQuality:face.faceCaptureQuality]];
    }
    NSArray<FaceRiskObservation *> *result = observations.copy;
    FaceAnalysisFrame *frame = self.identityAnalysisEnabled
        ? [[FaceAnalysisFrame alloc] initWithPixelBuffer:pixelBuffer observations:result timestamp:now]
        : nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate cameraService:self didDetectObservations:result];
        if (frame && [self.delegate respondsToSelector:@selector(cameraService:didAnalyzeFrame:)]) {
            [self.delegate cameraService:self didAnalyzeFrame:frame];
        }
    });
}

- (void)sessionWasInterrupted:(NSNotification *)notification {
    [self publishState:CameraServiceStateUnavailable message:@"摄像头暂时不可用"];
}

- (void)sessionInterruptionEnded:(NSNotification *)notification {
    if (self.wantsToRun) [self configureAndStart];
}

- (void)sessionRuntimeError:(NSNotification *)notification {
    [self publishState:CameraServiceStateFailed message:@"摄像头运行异常"];
    if (!self.wantsToRun) return;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(NSEC_PER_SEC)), self.sessionQueue, ^{
        [weakSelf configureAndStart];
    });
}

- (void)publishState:(CameraServiceState)state message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate cameraService:self didChangeState:state message:message];
    });
}

- (NSError *)errorWithDescription:(NSString *)description {
    return [NSError errorWithDomain:@"com.carlosli.WeChatPrivacyGuard.Camera"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

@end

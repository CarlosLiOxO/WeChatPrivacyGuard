#import "OwnerFaceEnrollmentWindowController.h"
#import "FaceCropNormalizer.h"
#import "FaceEmbeddingProvider.h"
#import "EnrollmentProgressEvaluator.h"
#import "FaceIdentityQuality.h"
#import "OwnerAwareRiskEvaluator.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const EnrollmentModelIdentifier = @"mobilefacenet-v1-coreml-fp16";
static const NSUInteger RequiredEnrollmentSamples = 9;

@interface EnrollmentRingView : NSView
@property(nonatomic) double progress;
@end

@implementation EnrollmentRingView
- (void)setProgress:(double)progress {
    _progress = MIN(1, MAX(0, progress));
    [self setNeedsDisplay:YES];
}
- (void)drawRect:(NSRect)dirtyRect {
    NSRect ringRect = NSInsetRect(self.bounds, 5, 5);
    NSBezierPath *track = [NSBezierPath bezierPathWithOvalInRect:ringRect];
    track.lineWidth = 6;
    [[NSColor separatorColor] setStroke];
    [track stroke];
    NSBezierPath *progress = [NSBezierPath bezierPath];
    [progress appendBezierPathWithArcWithCenter:NSMakePoint(NSMidX(ringRect), NSMidY(ringRect))
                                         radius:NSWidth(ringRect) / 2
                                     startAngle:90
                                       endAngle:90 - 360 * self.progress
                                      clockwise:YES];
    progress.lineWidth = 6;
    progress.lineCapStyle = NSLineCapStyleRound;
    [[NSColor systemTealColor] setStroke];
    [progress stroke];
}
@end

@interface EnrollmentCameraPreviewView : NSView
@property(nonatomic, strong, nullable) AVCaptureVideoPreviewLayer *previewLayer;
@end

@implementation EnrollmentCameraPreviewView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.cornerRadius = NSWidth(frameRect) / 2;
        self.layer.masksToBounds = YES;
        self.layer.backgroundColor = NSColor.controlBackgroundColor.CGColor;
    }
    return self;
}
- (void)setPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
    [_previewLayer removeFromSuperlayer];
    _previewLayer = previewLayer;
    if (previewLayer) {
        previewLayer.frame = self.bounds;
        [self.layer addSublayer:previewLayer];
    }
}
- (void)layout {
    [super layout];
    self.previewLayer.frame = self.bounds;
}
@end

@interface OwnerFaceEnrollmentWindowController ()
@property(nonatomic, strong) EnrollmentCameraPreviewView *previewView;
@property(nonatomic, strong) EnrollmentRingView *ringView;
@property(nonatomic, strong) NSTextField *instructionLabel;
@property(nonatomic, strong) NSTextField *detailLabel;
@property(nonatomic, strong) NSButton *cancelButton;
@property(nonatomic, strong) FaceCropNormalizer *cropNormalizer;
@property(nonatomic, strong) FaceEmbeddingProvider *embeddingProvider;
@property(nonatomic, strong) NSMutableArray<NSArray<NSNumber *> *> *templates;
@property(nonatomic) NSTimeInterval lastAcceptedTime;
@property(nonatomic) BOOL active;
@end

@implementation OwnerFaceEnrollmentWindowController

- (instancetype)initWithModelURL:(NSURL *)modelURL error:(NSError **)error {
    FaceEmbeddingProvider *provider = [[FaceEmbeddingProvider alloc] initWithModelURL:modelURL error:error];
    if (!provider) return nil;
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 520, 540)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                    backing:NSBackingStoreBuffered defer:NO];
    window.title = @"录入本人面容";
    window.releasedWhenClosed = NO;
    window.backgroundColor = NSColor.windowBackgroundColor;
    self = [super initWithWindow:window];
    if (self) {
        _embeddingProvider = provider;
        _cropNormalizer = [[FaceCropNormalizer alloc] init];
        _templates = [NSMutableArray array];
        window.delegate = (id<NSWindowDelegate>)self;
        [self buildInterface];
    }
    return self;
}

- (void)buildInterface {
    NSView *content = self.window.contentView;
    NSTextField *title = [NSTextField labelWithString:@"让守卫认识你"];
    title.font = [NSFont systemFontOfSize:24 weight:NSFontWeightSemibold];
    title.alignment = NSTextAlignmentCenter;
    title.frame = NSMakeRect(40, 482, 440, 34);
    [content addSubview:title];

    NSTextField *privacy = [NSTextField labelWithString:@"面容只在这台 Mac 上转换为特征并存入钥匙串，不保存照片，也不用于解锁。"];
    privacy.font = [NSFont systemFontOfSize:12];
    privacy.textColor = NSColor.secondaryLabelColor;
    privacy.alignment = NSTextAlignmentCenter;
    privacy.maximumNumberOfLines = 2;
    privacy.frame = NSMakeRect(60, 438, 400, 38);
    [content addSubview:privacy];

    self.previewView = [[EnrollmentCameraPreviewView alloc] initWithFrame:NSMakeRect(120, 145, 280, 280)];
    [content addSubview:self.previewView];

    self.ringView = [[EnrollmentRingView alloc] initWithFrame:NSMakeRect(112, 137, 296, 296)];
    self.ringView.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin;
    [content addSubview:self.ringView];

    self.instructionLabel = [NSTextField labelWithString:@"正视屏幕，保持一张脸在圆圈内"];
    self.instructionLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    self.instructionLabel.alignment = NSTextAlignmentCenter;
    self.instructionLabel.frame = NSMakeRect(40, 103, 440, 24);
    [content addSubview:self.instructionLabel];

    self.detailLabel = [NSTextField labelWithString:@"准备好后会自动开始"];
    self.detailLabel.font = [NSFont systemFontOfSize:12];
    self.detailLabel.textColor = NSColor.secondaryLabelColor;
    self.detailLabel.alignment = NSTextAlignmentCenter;
    self.detailLabel.frame = NSMakeRect(40, 78, 440, 20);
    [content addSubview:self.detailLabel];

    self.cancelButton = [NSButton buttonWithTitle:@"取消" target:self action:@selector(cancelEnrollment:)];
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.frame = NSMakeRect(210, 30, 100, 32);
    [content addSubview:self.cancelButton];
}

- (void)setCameraPreviewLayer:(AVCaptureVideoPreviewLayer *)cameraPreviewLayer {
    _cameraPreviewLayer = cameraPreviewLayer;
    self.previewView.previewLayer = cameraPreviewLayer;
}

- (void)beginEnrollment {
    [self.templates removeAllObjects];
    self.ringView.progress = 0;
    self.lastAcceptedTime = 0;
    self.active = YES;
    [self.window center];
    [NSApp activateIgnoringOtherApps:YES];
    [self showWindow:nil];
}

- (void)consumeFrame:(FaceAnalysisFrame *)frame {
    if (!self.active) return;
    if (frame.observations.count != 1) {
        self.detailLabel.stringValue = frame.observations.count == 0 ? @"请把脸移入圆圈" : @"画面中请只保留你本人";
        return;
    }
    FaceRiskObservation *face = frame.observations.firstObject;
    if (CGRectGetHeight(face.boundingBox) < 0.18) {
        self.detailLabel.stringValue = @"请靠近一点";
        return;
    }
    if (!FaceBoundingBoxSupportsReliableIdentityCrop(face.boundingBox)) {
        self.detailLabel.stringValue = @"请把完整面部保持在圆圈内";
        return;
    }
    if (!FaceCaptureQualitySupportsOwnerMatching(face.captureQuality)) {
        self.detailLabel.stringValue = @"请露出完整五官并保持画面清晰";
        return;
    }
    if (frame.timestamp - self.lastAcceptedTime < 0.45) return;
    if (!EnrollmentPoseAcceptsSample(self.templates.count, face.yaw)) {
        self.instructionLabel.stringValue = @"缓慢转动头部，保持注视屏幕";
        self.detailLabel.stringValue = @"圆环会在角度合适时继续";
        return;
    }

    NSError *error = nil;
    CVPixelBufferRef crop = [self.cropNormalizer createNormalizedFacePixelBufferFromSource:frame.pixelBuffer
        boundingBox:face.boundingBox error:&error];
    NSArray<NSNumber *> *embedding = crop
        ? [self.embeddingProvider embeddingForPixelBuffer:crop error:&error] : nil;
    if (crop) CVPixelBufferRelease(crop);
    if (!embedding) {
        self.detailLabel.stringValue = @"这一帧不够清晰，请保持稳定";
        return;
    }
    [self.templates addObject:embedding];
    self.lastAcceptedTime = frame.timestamp;
    self.ringView.progress = (double)self.templates.count / RequiredEnrollmentSamples;
    if (self.templates.count >= RequiredEnrollmentSamples) {
        [self finishEnrollment];
    } else if (self.templates.count == 1 || self.templates.count == 3 ||
               self.templates.count == 5 || self.templates.count == 7) {
        self.instructionLabel.stringValue = @"缓慢转动头部";
        self.detailLabel.stringValue = @"不用停下来，跟着圆环完成即可";
    } else {
        self.detailLabel.stringValue = @"很好，继续保持缓慢移动";
    }
}

- (void)finishEnrollment {
    OwnerFaceProfile *profile = [[OwnerFaceProfile alloc]
        initWithModelIdentifier:EnrollmentModelIdentifier ownerTemplates:self.templates.copy];
    self.active = NO;
    [self detachCameraPreview];
    self.instructionLabel.stringValue = @"录入完成";
    self.detailLabel.stringValue = @"本人特征已准备好保存";
    self.cancelButton.title = @"完成";
    void (^completion)(OwnerFaceProfile *) = self.completionHandler;
    [self close];
    if (profile && completion) completion(profile);
}

- (void)cancelEnrollment:(id)sender {
    BOOL wasActive = self.active;
    self.active = NO;
    [self detachCameraPreview];
    [self close];
    if (wasActive && self.cancellationHandler) self.cancellationHandler();
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    if (self.active) {
        self.active = NO;
        [self detachCameraPreview];
        if (self.cancellationHandler) self.cancellationHandler();
    }
    return YES;
}

- (void)detachCameraPreview {
    self.previewView.previewLayer = nil;
    self.cameraPreviewLayer = nil;
}

@end

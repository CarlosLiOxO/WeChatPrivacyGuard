#import "FaceCropNormalizer.h"
#import <CoreImage/CoreImage.h>

NSString *const FaceCropNormalizerErrorDomain = @"com.carlosli.WeChatPrivacyGuard.FaceCropNormalizer";
static const size_t NormalizedFaceSize = 112;

static NSError *FaceCropError(NSString *description) {
    return [NSError errorWithDomain:FaceCropNormalizerErrorDomain code:1
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

@interface FaceCropNormalizer ()
@property(nonatomic, strong) CIContext *context;
@end

@implementation FaceCropNormalizer

- (instancetype)init {
    self = [super init];
    if (self) _context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
    return self;
}

- (CVPixelBufferRef)createNormalizedFacePixelBufferFromSource:(CVPixelBufferRef)source
                                                   boundingBox:(CGRect)boundingBox
                                                         error:(NSError **)error {
    if (!source || CGRectIsEmpty(boundingBox) || CGRectIsNull(boundingBox)) {
        if (error) *error = FaceCropError(@"人脸区域无效");
        return nil;
    }
    CGFloat width = CVPixelBufferGetWidth(source);
    CGFloat height = CVPixelBufferGetHeight(source);
    CGRect faceRect = CGRectMake(boundingBox.origin.x * width,
                                 boundingBox.origin.y * height,
                                 boundingBox.size.width * width,
                                 boundingBox.size.height * height);
    CGFloat side = MAX(CGRectGetWidth(faceRect), CGRectGetHeight(faceRect)) * 1.38;
    CGPoint center = CGPointMake(CGRectGetMidX(faceRect), CGRectGetMidY(faceRect) + side * 0.03);
    CGRect square = CGRectMake(center.x - side / 2, center.y - side / 2, side, side);
    CGRect extent = CGRectMake(0, 0, width, height);
    square = CGRectIntersection(square, extent);
    if (CGRectIsEmpty(square) || CGRectGetWidth(square) < 8 || CGRectGetHeight(square) < 8) {
        if (error) *error = FaceCropError(@"人脸区域过小或超出画面");
        return nil;
    }

    CIImage *image = [CIImage imageWithCVPixelBuffer:source];
    CIImage *cropped = [image imageByCroppingToRect:square];
    CGFloat scale = MAX((CGFloat)NormalizedFaceSize / CGRectGetWidth(square),
                        (CGFloat)NormalizedFaceSize / CGRectGetHeight(square));
    CGAffineTransform transform = CGAffineTransformMake(
        scale, 0, 0, scale, -CGRectGetMinX(square) * scale, -CGRectGetMinY(square) * scale);
    CIImage *scaled = [cropped imageByApplyingTransform:transform];

    CVPixelBufferRef destination = nil;
    NSDictionary *attributes = @{
        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
    };
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault, NormalizedFaceSize, NormalizedFaceSize,
                                           kCVPixelFormatType_32BGRA,
                                           (__bridge CFDictionaryRef)attributes, &destination);
    if (result != kCVReturnSuccess || !destination) {
        if (error) *error = FaceCropError(@"无法创建人脸推理缓冲区");
        return nil;
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    [self.context render:scaled toCVPixelBuffer:destination
                   bounds:CGRectMake(0, 0, NormalizedFaceSize, NormalizedFaceSize)
               colorSpace:colorSpace];
    CGColorSpaceRelease(colorSpace);
    return destination;
}

@end

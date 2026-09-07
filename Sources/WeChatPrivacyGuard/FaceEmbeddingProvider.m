#import "FaceEmbeddingProvider.h"
#import <math.h>

NSString *const FaceEmbeddingProviderErrorDomain = @"com.carlosli.WeChatPrivacyGuard.FaceEmbeddingProvider";
static NSString *const FaceEmbeddingInputName = @"face_image";
static NSString *const FaceEmbeddingOutputName = @"embedding";

static NSError *FaceEmbeddingError(NSInteger code, NSString *description) {
    return [NSError errorWithDomain:FaceEmbeddingProviderErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

@interface FaceEmbeddingProvider ()
@property(nonatomic, strong) MLModel *model;
@property(nonatomic, strong) NSLock *inferenceLock;
@property(nonatomic, readwrite) NSUInteger embeddingDimension;
@end

@implementation FaceEmbeddingProvider

- (instancetype)initWithModelURL:(NSURL *)modelURL error:(NSError **)error {
    NSURL *loadURL = modelURL;
    if (![modelURL.pathExtension isEqualToString:@"mlmodelc"]) {
        loadURL = [MLModel compileModelAtURL:modelURL error:error];
        if (!loadURL) return nil;
    }
    MLModelConfiguration *configuration = [[MLModelConfiguration alloc] init];
    configuration.computeUnits = MLComputeUnitsAll;
    MLModel *model = [MLModel modelWithContentsOfURL:loadURL configuration:configuration error:error];
    if (!model) return nil;
    MLFeatureDescription *output = model.modelDescription.outputDescriptionsByName[FaceEmbeddingOutputName];
    NSArray<NSNumber *> *shape = output.multiArrayConstraint.shape;
    NSUInteger dimension = shape.lastObject.unsignedIntegerValue;
    if (output.type != MLFeatureTypeMultiArray || dimension == 0) {
        if (error) *error = FaceEmbeddingError(1, @"人脸模型输出格式无效");
        return nil;
    }
    self = [super init];
    if (self) {
        _model = model;
        _inferenceLock = [[NSLock alloc] init];
        _embeddingDimension = dimension;
    }
    return self;
}

- (NSArray<NSNumber *> *)embeddingForPixelBuffer:(CVPixelBufferRef)pixelBuffer error:(NSError **)error {
    if (![self.inferenceLock tryLock]) {
        if (error) *error = FaceEmbeddingError(2, @"人脸推理忙，已丢弃当前帧");
        return nil;
    }
    @try {
        MLFeatureValue *inputValue = [MLFeatureValue featureValueWithPixelBuffer:pixelBuffer];
        MLDictionaryFeatureProvider *input = [[MLDictionaryFeatureProvider alloc]
            initWithDictionary:@{FaceEmbeddingInputName: inputValue} error:error];
        if (!input) return nil;
        id<MLFeatureProvider> output = [self.model predictionFromFeatures:input error:error];
        MLMultiArray *values = [output featureValueForName:FaceEmbeddingOutputName].multiArrayValue;
        NSUInteger valueCount = (NSUInteger)values.count;
        if (!values || valueCount != self.embeddingDimension) {
            if (error) *error = FaceEmbeddingError(3, @"人脸模型返回了错误维度");
            return nil;
        }
        NSMutableArray<NSNumber *> *embedding = [NSMutableArray arrayWithCapacity:values.count];
        double normSquared = 0;
        for (NSUInteger index = 0; index < valueCount; index++) {
            double value = values[index].doubleValue;
            if (!isfinite(value)) {
                if (error) *error = FaceEmbeddingError(4, @"人脸模型返回了非法数值");
                return nil;
            }
            normSquared += value * value;
            [embedding addObject:@(value)];
        }
        double norm = sqrt(normSquared);
        if (!isfinite(norm) || norm < 1e-8) {
            if (error) *error = FaceEmbeddingError(5, @"人脸特征向量无效");
            return nil;
        }
        for (NSUInteger index = 0; index < embedding.count; index++) {
            embedding[index] = @(embedding[index].doubleValue / norm);
        }
        return embedding.copy;
    } @finally {
        [self.inferenceLock unlock];
    }
}

@end

#import "OwnerAwareFaceCoordinator.h"
#import "FaceCropNormalizer.h"
#import "FaceEmbeddingProvider.h"
#import "FaceIdentityCache.h"
#import "FaceIdentityQuality.h"
#import "OwnerAwareRiskEvaluator.h"
#import "OwnerFaceMatcher.h"
#import "OwnerIdentityStabilizer.h"
#import <math.h>

// Development thresholds. They must be calibrated on a disjoint local set before release.
static const double DevelopmentOwnerSimilarityThreshold = 0.72;
static const double DevelopmentUnknownSimilarityThreshold = 0.62;
static const CGFloat MinimumInferenceFaceArea = 0.001;

@interface OwnerAwareFaceCoordinator ()
@property(nonatomic, strong) OwnerFaceMatcher *matcher;
@property(nonatomic, strong) OwnerAwareRiskEvaluator *riskEvaluator;
@property(nonatomic, strong) FaceIdentityCache *identityCache;
@property(nonatomic, strong) FaceCropNormalizer *cropNormalizer;
@property(nonatomic, strong) FaceEmbeddingProvider *embeddingProvider;
@property(nonatomic, strong) OwnerIdentityStabilizer *identityStabilizer;
@end

@implementation OwnerAwareFaceCoordinator

- (instancetype)initWithProfile:(OwnerFaceProfile *)profile
                         modelURL:(NSURL *)modelURL
               protectionDistance:(ProtectionDistance)protectionDistance
                            error:(NSError **)error {
    FaceEmbeddingProvider *provider = [[FaceEmbeddingProvider alloc] initWithModelURL:modelURL error:error];
    if (!provider || provider.embeddingDimension != profile.embeddingDimension) return nil;
    self = [super init];
    if (self) {
        _embeddingProvider = provider;
        _cropNormalizer = [[FaceCropNormalizer alloc] init];
        _matcher = [[OwnerFaceMatcher alloc]
            initWithOwnerTemplates:profile.ownerTemplates
            ownerSimilarityThreshold:DevelopmentOwnerSimilarityThreshold
            unknownSimilarityThreshold:DevelopmentUnknownSimilarityThreshold];
        _riskEvaluator = [[OwnerAwareRiskEvaluator alloc] initWithProtectionDistance:protectionDistance];
        _identityCache = [[FaceIdentityCache alloc] initWithTimeToLive:0.30 minimumOverlapRatio:0.30];
        _identityStabilizer = [[OwnerIdentityStabilizer alloc]
            initWithRequiredUnknownObservations:3
            minimumUnknownDuration:0.18
            maximumObservationGap:0.35
            maximumOwnerTrackGap:0.45];
        _protectionDistance = protectionDistance;
    }
    return self;
}

- (void)setProtectionDistance:(ProtectionDistance)protectionDistance {
    _protectionDistance = protectionDistance;
    self.riskEvaluator.protectionDistance = protectionDistance;
}

- (FaceRiskState)evaluateFrame:(FaceAnalysisFrame *)frame {
    if (frame.observations.count > 4) return FaceRiskStatePresent;
    NSMutableArray<FaceRiskObservation *> *eligibleFaces = [NSMutableArray array];
    for (FaceRiskObservation *face in frame.observations) {
        CGFloat width = CGRectGetWidth(face.boundingBox);
        CGFloat height = CGRectGetHeight(face.boundingBox);
        CGFloat area = width * height;
        CGFloat minimumHeight = FaceHeightThresholdForProtectionDistance(self.protectionDistance) * 0.85;
        if (!isfinite(width) || !isfinite(height) || area < MinimumInferenceFaceArea ||
            height < minimumHeight ||
            !OwnerAwareFaceCanTriggerPrivacy(face.boundingBox, face.yaw)) {
            continue;
        }

        [eligibleFaces addObject:face];
    }

    if (eligibleFaces.count > 1) {
        // When two faces can view the screen, identity inference is unnecessary: mark the
        // largest face as the owner candidate and protect based on every additional face.
        [self.identityStabilizer reset];
        FaceRiskObservation *largest = [eligibleFaces sortedArrayUsingComparator:^NSComparisonResult(
            FaceRiskObservation *left, FaceRiskObservation *right) {
            CGFloat leftArea = CGRectGetWidth(left.boundingBox) * CGRectGetHeight(left.boundingBox);
            CGFloat rightArea = CGRectGetWidth(right.boundingBox) * CGRectGetHeight(right.boundingBox);
            if (leftArea > rightArea) return NSOrderedAscending;
            if (leftArea < rightArea) return NSOrderedDescending;
            return NSOrderedSame;
        }].firstObject;
        NSMutableArray<OwnerAwareFaceObservation *> *multiple = [NSMutableArray array];
        for (FaceRiskObservation *face in eligibleFaces) {
            FaceIdentityResult identity = face == largest
                ? FaceIdentityResultOwner : FaceIdentityResultAmbiguous;
            [multiple addObject:[[OwnerAwareFaceObservation alloc]
                initWithBoundingBox:face.boundingBox yaw:face.yaw identityResult:identity]];
        }
        return [self.riskEvaluator evaluateObservations:multiple];
    }

    if (eligibleFaces.count == 0) return FaceRiskStateNone;
    FaceRiskObservation *face = eligibleFaces.firstObject;
    NSNumber *cached = [self.identityCache cachedIdentityForBoundingBox:face.boundingBox
                                                                  atTime:frame.timestamp];
    FaceIdentityResult rawIdentity = cached ? cached.integerValue : FaceIdentityResultAmbiguous;
    if (!cached && FaceCaptureQualitySupportsOwnerMatching(face.captureQuality)) {
        NSError *error = nil;
        CVPixelBufferRef crop = [self.cropNormalizer
            createNormalizedFacePixelBufferFromSource:frame.pixelBuffer
                                           boundingBox:face.boundingBox error:&error];
        NSArray<NSNumber *> *embedding = crop
            ? [self.embeddingProvider embeddingForPixelBuffer:crop error:&error] : nil;
        if (crop) CVPixelBufferRelease(crop);
        rawIdentity = embedding ? [self.matcher classifyEmbedding:embedding] : FaceIdentityResultAmbiguous;
        // Lower-quality frames may confirm a matching owner, but cannot accumulate
        // evidence against the owner. This prevents hand occlusion or facial
        // distortion from becoming a false stranger decision.
        rawIdentity = FaceIdentityResultRespectingCaptureQuality(rawIdentity,
                                                                 face.captureQuality);
        // Only confirmed owner identities are cached. A single distorted frame must not
        // turn into 0.9 seconds of repeated "unknown" evidence.
        if (rawIdentity == FaceIdentityResultOwner) {
            [self.identityCache storeIdentity:rawIdentity boundingBox:face.boundingBox atTime:frame.timestamp];
        }
    }
    FaceIdentityResult identity = [self.identityStabilizer
        stabilizedIdentityForRawIdentity:rawIdentity
        boundingBox:face.boundingBox
        atTime:frame.timestamp];
    OwnerAwareFaceObservation *identified = [[OwnerAwareFaceObservation alloc]
        initWithBoundingBox:face.boundingBox yaw:face.yaw identityResult:identity];
    return [self.riskEvaluator evaluateObservations:@[identified]];
}

- (void)reset {
    [self.identityCache reset];
    [self.identityStabilizer reset];
}

@end

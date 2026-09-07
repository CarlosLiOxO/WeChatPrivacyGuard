#import "OwnerFaceMatcher.h"
#import <float.h>
#import <math.h>

static const double MinimumVectorNorm = 1e-8;

@interface OwnerFaceMatcher ()
@property(nonatomic, copy) NSArray<NSArray<NSNumber *> *> *ownerTemplates;
@property(nonatomic) double ownerSimilarityThreshold;
@property(nonatomic) double unknownSimilarityThreshold;
@property(nonatomic, readwrite) NSUInteger embeddingDimension;
@end

@implementation OwnerFaceMatcher

- (instancetype)initWithOwnerTemplates:(NSArray<NSArray<NSNumber *> *> *)ownerTemplates
               ownerSimilarityThreshold:(double)ownerSimilarityThreshold
             unknownSimilarityThreshold:(double)unknownSimilarityThreshold {
    self = [super init];
    if (self) {
        _ownerTemplates = [ownerTemplates copy];
        _embeddingDimension = ownerTemplates.firstObject.count;
        _ownerSimilarityThreshold = ownerSimilarityThreshold;
        _unknownSimilarityThreshold = unknownSimilarityThreshold;
    }
    return self;
}

- (FaceIdentityResult)classifyEmbedding:(NSArray<NSNumber *> *)embedding {
    BOOL valid = NO;
    double similarity = [self maximumSimilarityForEmbedding:embedding valid:&valid];
    if (!valid || !isfinite(self.ownerSimilarityThreshold) ||
        !isfinite(self.unknownSimilarityThreshold) ||
        self.unknownSimilarityThreshold >= self.ownerSimilarityThreshold) {
        return FaceIdentityResultAmbiguous;
    }
    if (similarity >= self.ownerSimilarityThreshold) return FaceIdentityResultOwner;
    if (similarity <= self.unknownSimilarityThreshold) return FaceIdentityResultUnknown;
    return FaceIdentityResultAmbiguous;
}

- (double)maximumSimilarityForEmbedding:(NSArray<NSNumber *> *)embedding valid:(BOOL *)valid {
    if (valid) *valid = NO;
    if (self.ownerTemplates.count == 0 || self.embeddingDimension == 0 ||
        embedding.count != self.embeddingDimension) {
        return NAN;
    }

    double maximumSimilarity = -DBL_MAX;
    for (NSArray<NSNumber *> *template in self.ownerTemplates) {
        if (template.count != self.embeddingDimension) return NAN;
        double dotProduct = 0;
        double leftNormSquared = 0;
        double rightNormSquared = 0;
        for (NSUInteger index = 0; index < self.embeddingDimension; index++) {
            double left = embedding[index].doubleValue;
            double right = template[index].doubleValue;
            if (!isfinite(left) || !isfinite(right)) return NAN;
            dotProduct += left * right;
            leftNormSquared += left * left;
            rightNormSquared += right * right;
        }
        double denominator = sqrt(leftNormSquared) * sqrt(rightNormSquared);
        if (!isfinite(denominator) || denominator < MinimumVectorNorm) return NAN;
        maximumSimilarity = MAX(maximumSimilarity, dotProduct / denominator);
    }
    if (valid) *valid = isfinite(maximumSimilarity);
    return maximumSimilarity;
}

@end

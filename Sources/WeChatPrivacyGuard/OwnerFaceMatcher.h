#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FaceIdentityResult) {
    FaceIdentityResultOwner = 0,
    FaceIdentityResultUnknown = 1,
    FaceIdentityResultAmbiguous = 2,
};

@interface OwnerFaceMatcher : NSObject

@property(nonatomic, readonly) NSUInteger embeddingDimension;

- (instancetype)initWithOwnerTemplates:(NSArray<NSArray<NSNumber *> *> *)ownerTemplates
               ownerSimilarityThreshold:(double)ownerSimilarityThreshold
             unknownSimilarityThreshold:(double)unknownSimilarityThreshold;
- (FaceIdentityResult)classifyEmbedding:(NSArray<NSNumber *> *)embedding;
- (double)maximumSimilarityForEmbedding:(NSArray<NSNumber *> *)embedding valid:(BOOL *)valid;

@end

NS_ASSUME_NONNULL_END

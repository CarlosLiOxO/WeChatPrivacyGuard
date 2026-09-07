#import "FaceIdentityCache.h"

@interface FaceIdentityCacheEntry : NSObject
@property(nonatomic) CGRect boundingBox;
@property(nonatomic) FaceIdentityResult identity;
@property(nonatomic) NSTimeInterval timestamp;
@end
@implementation FaceIdentityCacheEntry
@end

static CGFloat FaceIdentityIntersectionOverUnion(CGRect left, CGRect right) {
    CGRect intersection = CGRectIntersection(left, right);
    if (CGRectIsNull(intersection) || CGRectIsEmpty(intersection)) return 0;
    CGFloat intersectionArea = CGRectGetWidth(intersection) * CGRectGetHeight(intersection);
    CGFloat leftArea = CGRectGetWidth(left) * CGRectGetHeight(left);
    CGFloat rightArea = CGRectGetWidth(right) * CGRectGetHeight(right);
    CGFloat unionArea = leftArea + rightArea - intersectionArea;
    return unionArea > 0 ? intersectionArea / unionArea : 0;
}

@interface FaceIdentityCache ()
@property(nonatomic) NSTimeInterval timeToLive;
@property(nonatomic) CGFloat minimumOverlapRatio;
@property(nonatomic, strong) NSMutableArray<FaceIdentityCacheEntry *> *entries;
@end

@implementation FaceIdentityCache

- (instancetype)initWithTimeToLive:(NSTimeInterval)timeToLive
                 minimumOverlapRatio:(CGFloat)minimumOverlapRatio {
    self = [super init];
    if (self) {
        _timeToLive = MAX(0, timeToLive);
        _minimumOverlapRatio = MIN(1, MAX(0, minimumOverlapRatio));
        _entries = [NSMutableArray array];
    }
    return self;
}

- (NSUInteger)count {
    return self.entries.count;
}

- (void)storeIdentity:(FaceIdentityResult)identity
          boundingBox:(CGRect)boundingBox
               atTime:(NSTimeInterval)time {
    [self removeExpiredEntriesAtTime:time];
    FaceIdentityCacheEntry *bestEntry = nil;
    CGFloat bestOverlap = 0;
    for (FaceIdentityCacheEntry *entry in self.entries) {
        CGFloat overlap = FaceIdentityIntersectionOverUnion(entry.boundingBox, boundingBox);
        if (overlap >= self.minimumOverlapRatio && overlap > bestOverlap) {
            bestEntry = entry;
            bestOverlap = overlap;
        }
    }
    if (!bestEntry) {
        bestEntry = [[FaceIdentityCacheEntry alloc] init];
        [self.entries addObject:bestEntry];
    }
    bestEntry.boundingBox = boundingBox;
    bestEntry.identity = identity;
    bestEntry.timestamp = time;
}

- (NSNumber *)cachedIdentityForBoundingBox:(CGRect)boundingBox atTime:(NSTimeInterval)time {
    [self removeExpiredEntriesAtTime:time];
    FaceIdentityCacheEntry *bestEntry = nil;
    CGFloat bestOverlap = 0;
    for (FaceIdentityCacheEntry *entry in self.entries) {
        CGFloat overlap = FaceIdentityIntersectionOverUnion(entry.boundingBox, boundingBox);
        if (overlap >= self.minimumOverlapRatio && overlap > bestOverlap) {
            bestEntry = entry;
            bestOverlap = overlap;
        }
    }
    return bestEntry ? @(bestEntry.identity) : nil;
}

- (void)removeExpiredEntriesAtTime:(NSTimeInterval)time {
    NSIndexSet *expired = [self.entries indexesOfObjectsPassingTest:^BOOL(
        FaceIdentityCacheEntry *entry, NSUInteger index, BOOL *stop) {
        (void)index;
        (void)stop;
        return time < entry.timestamp || time - entry.timestamp > self.timeToLive;
    }];
    if (expired.count > 0) [self.entries removeObjectsAtIndexes:expired];
}

- (void)reset {
    [self.entries removeAllObjects];
}

@end

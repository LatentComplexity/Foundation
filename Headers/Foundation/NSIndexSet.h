
#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Immutable Index Set

@interface NSIndexSet : NSObject <NSCopying, NSMutableCopying>

@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSUInteger firstIndex;
@property (nonatomic, readonly) NSUInteger lastIndex;

+ (instancetype)indexSet;

+ (instancetype)indexSetWithIndex:(NSUInteger)index;

+ (instancetype)indexSetWithIndexesInRange:(NSRange)range;

- (instancetype)initWithIndexSet:(NSIndexSet *)indexSet;

- (instancetype)initWithIndex:(NSUInteger)index;

- (instancetype)initWithIndexesInRange:(NSRange)range;

- (NSUInteger)getIndexes:(NSUInteger *)indexBuffer maxCount:(NSUInteger)bufferSize
		inIndexRange:(nullable NSRange *)rangePointer;

- (bool)containsIndex:(NSUInteger)anIndex;

- (bool)containsIndexes:(NSIndexSet *)indexSet;

- (bool)containsIndexesInRange:(NSRange)range;

- (bool)intersectsIndexesInRange:(NSRange)range;

- (NSUInteger)indexGreaterThanIndex:(NSUInteger)anIndex;

- (NSUInteger)indexLessThanIndex:(NSUInteger)anIndex;

- (NSUInteger)indexGreaterThanOrEqualToIndex:(NSUInteger)anIndex;

- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)anIndex;

- (NSUInteger)countOfIndexesInRange:(NSRange)range;

- (NSUInteger)indexPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate;

- (NSUInteger)indexWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate;

- (NSUInteger)indexInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate;

- (NSIndexSet *)indexesPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate;

- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate;

- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate;

- (void)enumerateIndexesUsingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block;

- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block;

- (void)enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block;

- (void)enumerateRangesUsingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block;

- (void)enumerateRangesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block;

- (void)enumerateRangesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block;

- (bool)isEqualToIndexSet:(NSIndexSet *)indexSet;

@end

#pragma mark - Mutable Index Set

@interface NSMutableIndexSet : NSIndexSet

- (void)addIndexes:(NSIndexSet *)indexSet;

- (void)removeIndexes:(NSIndexSet *)indexSet;

- (void)removeAllIndexes;

- (void)addIndex:(NSUInteger)anIndex;

- (void)removeIndex:(NSUInteger)anIndex;

- (void)addIndexesInRange:(NSRange)range;

- (void)removeIndexesInRange:(NSRange)range;

- (void)shiftIndexesStartingAtIndex:(NSUInteger)anIndex by:(NSInteger)delta;

@end

NS_ASSUME_NONNULL_END

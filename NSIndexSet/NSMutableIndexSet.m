
#import <FoundationPrivate/NSIndexSet/NSIndexSet.h>

@implementation NSMutableIndexSet

static NSMutableIndexSetTemplate *_NSMutableIndexSetTemplateInstance = nil;

+ (void)initialize
{
	static NSCallOnceState s = {};

	if (self == [NSMutableIndexSet class])
		NSCallOnce(&s, ^{
			_NSMutableIndexSetTemplateInstance = [NSMutableIndexSetTemplate alloc];
		});
}

+ (instancetype)alloc
{
	if (self == _NSMutableIndexSetClass)
		return _NSMutableIndexSetTemplateInstance;

	return class_createInstance(self, 0);
}

- (id)copy
{
	_NSMutableIndexSetRejectInvocation();
}

- (id)mutableCopy
{
	_NSMutableIndexSetRejectInvocation();
}

+ (instancetype)indexSet
{
	return [[self alloc] init];
}

+ (instancetype)indexSetWithIndex:(NSUInteger)index
{
	return [[self alloc] initWithIndex:index];
}

+ (instancetype)indexSetWithIndexesInRange:(NSRange)range
{
	return [[self alloc] initWithIndexesInRange:range];
}

- (instancetype)init
{
	_NSMutableIndexSetRejectReinitialization();
}

- (instancetype)initWithIndexSet:(NSIndexSet *)indexSet
{
	_NSMutableIndexSetRejectReinitialization();
}

- (instancetype)initWithIndex:(NSUInteger)index
{
	_NSMutableIndexSetRejectReinitialization();
}

- (instancetype)initWithIndexesInRange:(NSRange)range
{
	_NSMutableIndexSetRejectReinitialization();
}

- (NSUInteger)count
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)firstIndex
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)lastIndex
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)getIndexes:(NSUInteger *)indexBuffer maxCount:(NSUInteger)bufferSize
		inIndexRange:(nullable NSRange *)rangePointer
{
	_NSMutableIndexSetRejectInvocation();
}

- (bool)containsIndex:(NSUInteger)anIndex
{
	_NSMutableIndexSetRejectInvocation();
}

- (bool)containsIndexes:(NSIndexSet *)indexSet
{
	_NSMutableIndexSetRejectInvocation();
}

- (bool)containsIndexesInRange:(NSRange)range
{
	_NSMutableIndexSetRejectInvocation();
}

- (bool)intersectsIndexesInRange:(NSRange)range
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)indexGreaterThanIndex:(NSUInteger)anIndex
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)indexLessThanIndex:(NSUInteger)anIndex
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)indexGreaterThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)countOfIndexesInRange:(NSRange)range
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)indexPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)indexWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)indexInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSIndexSet *)indexesPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)enumerateIndexesUsingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)enumerateRangesUsingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)enumerateRangesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)enumerateRangesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (NSUInteger)hash
{
	_NSMutableIndexSetRejectInvocation();
}

- (bool)isEqualToIndexSet:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	_NSMutableIndexSetRejectInvocation();
}

- (void)addIndexes:(NSIndexSet *)indexSet NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)removeIndexes:(NSIndexSet *)indexSet NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)removeAllIndexes NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)addIndex:(NSUInteger)anIndex NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)removeIndex:(NSUInteger)anIndex NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)addIndexesInRange:(NSRange)range NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)removeIndexesInRange:(NSRange)range NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

- (void)shiftIndexesStartingAtIndex:(NSUInteger)anIndex by:(NSInteger)delta NS_NORETURN
{
	_NSMutableIndexSetRejectInvocation();
}

@end

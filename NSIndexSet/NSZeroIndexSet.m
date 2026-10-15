
#import <FoundationPrivate/NSIndexSet/NSIndexSet.h>

@implementation NSZeroIndexSet

- (id)copy
{
	return self;
}

- (id)mutableCopy
{
	return [[NSMutableInlineIndexSet alloc] _initWithIndexRanges:nullptr rangeCount:0 count:0];
}

- (NSUInteger)count
{
	return 0;
}

- (NSUInteger)firstIndex
{
	return NSNotFound;
}

- (NSUInteger)lastIndex
{
	return NSNotFound;
}

- (NSUInteger)getIndexes:(NSUInteger *)indexBuffer maxCount:(NSUInteger)bufferSize
		inIndexRange:(nullable NSRange *)rangePointer
{
	_NSRequireNonnullptr(indexBuffer);

	if (rangePointer != nil)
		_NSRangeWithinUpperBound((*rangePointer), (NSUInteger)NSNotFound);

	/* We don't touch the range pointer since we moved nothing. */
	return 0;
}

- (bool)containsIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return false;
}

- (bool)containsIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	if ((uintptr_t)self == (uintptr_t)indexSet)
		return true;

	Class const c = object_getClass(indexSet);

	/* Set theory says the empty set is a subset of every set, including itself. */
	if (c == _NSZeroIndexSetClass)
		return true;

	if (c == _NSMutableInlineIndexSetClass)
		return ((__bridge NSInlineIndexSetLayout *)indexSet)->count == 0;

	return false;
}

- (bool)containsIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	/*
	 * -containsIndexesInRange: checks if the receiver contains the entire span of numbers defined by that range.
	 * Because an empty index set contains absolutely no indexes, it cannot contain any range, even an empty one.
	 */
	return false;
}

- (bool)intersectsIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	return false;
}

- (NSUInteger)indexGreaterThanIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return NSNotFound;
}

- (NSUInteger)indexLessThanIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return NSNotFound;
}

- (NSUInteger)indexGreaterThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return NSNotFound;
}

- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return NSNotFound;
}

- (NSUInteger)countOfIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	return 0;
}

- (NSUInteger)indexPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return NSNotFound;
}

- (NSUInteger)indexWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return NSNotFound;
}

- (NSUInteger)indexInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return NSNotFound;
}

- (NSIndexSet *)indexesPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSZeroIndexSetInstance;
}

- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSZeroIndexSetInstance;
}

- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSZeroIndexSetInstance;
}

- (void)enumerateIndexesUsingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	return;
}

- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	return;
}

- (void)enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	return;
}

- (void)enumerateRangesUsingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSRequireNonnil(block);

	return;
}

- (void)enumerateRangesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	return;
}

- (void)enumerateRangesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	return;
}

- (NSUInteger)hash
{
	return _NSZeroIndexSetHash;
}

- (bool)isEqualToIndexSet:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	if ((uintptr_t)self == (uintptr_t)indexSet)
		return true;

	Class const c = object_getClass(indexSet);

	if (c == _NSMutableInlineIndexSetClass)
		return ((__bridge NSInlineIndexSetLayout *)indexSet)->count == 0;

	/*
	 * The odds that someone creates a new instance of the zero index set class are infinitesimally small, so
	 * check if the class is a mutable index set holding nothing before this.
	 */
	if (c == _NSZeroIndexSetClass)
		return true;

	return false;
}

@end

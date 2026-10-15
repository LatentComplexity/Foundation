
#import <FoundationPrivate/NSIndexSet/NSIndexSet.h>

@implementation NSSingleEntryIndexSet {
	NSUInteger _index;
}

- (instancetype)_initWithIndex:(NSUInteger)index OBJC_DIRECT
{
	_index = index;

	return self;
}

- (id)copy
{
	return self;
}

- (id)mutableCopy
{
	return [[NSMutableInlineIndexSet alloc] _initWithIndex:_index];
}

- (NSUInteger)count
{
	return 1;
}

- (NSUInteger)firstIndex
{
	return _index;
}

- (NSUInteger)lastIndex
{
	return _index;
}

- (NSUInteger)getIndexes:(NSUInteger *)indexBuffer maxCount:(NSUInteger)bufferSize
		inIndexRange:(nullable NSRange *)rangePointer
{
	_NSRequireNonnullptr(indexBuffer);

	NSRange const oldRange = rangePointer != nil ? *rangePointer : NSRangeZero;

	if (rangePointer != nil)
		_NSRangeWithinUpperBound(oldRange, (NSUInteger)NSNotFound);

	if (bufferSize == 0)
		return 0;

	if (rangePointer != nil && NSRangeContainsLocation(oldRange, _index) == false)
		return 0;

	indexBuffer[0] = _index;

	if (rangePointer != nil)
		*rangePointer = NSRangeMake(_index + 1, NSRangeMax(oldRange) - (_index + 1));

	return 1;
}

- (bool)containsIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return _index == anIndex;
}

- (bool)containsIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	Class const c = object_getClass(indexSet);

	if (c == _NSZeroIndexSetClass)
		return true;

	if (c == _NSSingleEntryIndexSetClass)
		return _index == ((__bridge NSSingleEntryIndexSetLayout *)indexSet)->index;

	if (c == _NSMutableInlineIndexSetClass) {
		NSInlineIndexSetLayout const *const idxSet = (__bridge NSInlineIndexSetLayout *)indexSet;
		return idxSet->count == 0 || (idxSet->count == 1 && idxSet->ranges[0].location == _index);
	}

	return false;
}

- (bool)containsIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	return range.location == _index && range.length == 1;
}

- (bool)intersectsIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	return NSRangeContainsLocation(range, _index);
}

- (NSUInteger)indexGreaterThanIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return anIndex < _index ? _index : NSNotFound;
}

- (NSUInteger)indexLessThanIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return anIndex > _index ? _index : NSNotFound;
}

- (NSUInteger)indexGreaterThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return anIndex <= _index ? _index : NSNotFound;
}

- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return anIndex >= _index ? _index : NSNotFound;
}

- (NSUInteger)countOfIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	return NSRangeContainsLocation(range, _index) ? 1 : 0;
}

- (NSUInteger)indexPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return predicate(_index, (bool[]){ false }) == true ? _index : NSNotFound;
}

- (NSUInteger)indexWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return predicate(_index, (bool[]){ false }) == true ? _index : NSNotFound;
}

- (NSUInteger)indexInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	if (NSRangeContainsLocation(range, _index))
		if (predicate(_index, (bool[]){ false }) == true)
			return _index;

	return NSNotFound;
}

- (NSIndexSet *)indexesPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return predicate(_index, (bool[]){ false }) == true ? (id)self : (id)_NSZeroIndexSetInstance;
}

- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return predicate(_index, (bool[]){ false }) == true ? (id)self : (id)_NSZeroIndexSetInstance;
}

- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	if (NSRangeContainsLocation(range, _index))
		if (predicate(_index, (bool[]){ false }) == true)
			return (id)self;

	return (id)_NSZeroIndexSetInstance;
}

- (void)enumerateIndexesUsingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	block(_index, (bool[]){ false });
}

- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	block(_index, (bool[]){ false });
}

- (void)enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	if (NSRangeContainsLocation(range, _index))
		block(_index, (bool[]){ false });
}

- (void)enumerateRangesUsingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSRequireNonnil(block);

	block(NSRangeMake(_index, 1), (bool[]){ false });
}

- (void)enumerateRangesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	block(NSRangeMake(_index, 1), (bool[]){ false });
}

- (void)enumerateRangesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	if (NSRangeContainsLocation(range, _index))
		block(NSRangeMake(_index, 1), (bool[]){ false });
}

- (NSUInteger)hash
{
	return NSSipHash((NSUInteger[]){ _index, 1 }, 2 * sizeof(NSUInteger), _NSIndexSetHashKey);
}

- (bool)isEqualToIndexSet:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	if ((uintptr_t)self == (uintptr_t)indexSet)
		return true;

	Class const c = object_getClass(indexSet);

	if (c == _NSSingleEntryIndexSetClass)
		return _index == ((__bridge NSSingleEntryIndexSetLayout *)indexSet)->index;

	if (c == _NSMutableInlineIndexSetClass) {
		NSInlineIndexSetLayout const *const idxSet = (__bridge NSInlineIndexSetLayout *)indexSet;
		return idxSet->count == 1 && idxSet->ranges[0].location == _index;
	}

	return false;
}

@end


#import <FoundationPrivate/NSIndexSet/NSIndexSet.h>

@implementation NSInlineIndexSet {
	NSRange const *_ranges;
	NSUInteger _rangeCount;
	NSUInteger _count;
	NSUInteger _Atomic _hash;
}

/* The source always comes from an existing mutable range buffer. */
- (instancetype)_initWithIndexRanges:(const NSRange *)ranges rangeCount:(NSUInteger)rangeCount
		count:(NSUInteger)count OBJC_DIRECT
{
	NSUInteger const byteCount = rangeCount * sizeof(NSRange);
	NSRange *r = _NSMalloc(byteCount);

	memcpy(r, ranges, byteCount);
	_ranges = r;
	_rangeCount = rangeCount;
	_count = count;

	return self;
}

- (instancetype)_initAdoptingIndexRanges:(NSRange *)ranges rangeCount:(NSUInteger)rangeCount
		count:(NSUInteger)count OBJC_DIRECT
{
	_ranges = ranges;
	_rangeCount = rangeCount;
	_count = count;

	return self;
}

- (id)copy
{
	return self;
}

- (id)mutableCopy
{
	return [[NSMutableInlineIndexSet alloc] _initWithIndexRanges:_ranges rangeCount:_rangeCount count:_count];
}

- (NSUInteger)count
{
	return _count;
}

- (NSUInteger)firstIndex
{
	return _ranges[0].location;
}

- (NSUInteger)lastIndex
{
	return NSRangeMax(_ranges[_rangeCount - 1]) - 1;
}

- (NSUInteger)getIndexes:(NSUInteger *)indexBuffer maxCount:(NSUInteger)bufferSize
		inIndexRange:(nullable NSRange *)rangePointer
{
	_NSRequireNonnullptr(indexBuffer);

	return _NSIndexSetGetIndexesInRange(((NSIndexSetRepresentation) { .indexSet = nil, .indexSetCls = Nil,
		.r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}), indexBuffer, bufferSize, rangePointer);
}

- (bool)containsIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	bool isContained = false;
	(void)_NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, anIndex, &isContained);

	return isContained;
}

- (bool)containsIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	if ((uintptr_t)self == (uintptr_t)indexSet)
		return true;

	return _NSIndexSetContainsIndexes((NSIndexSetRepresentation) { .indexSet = nil, .indexSetCls = Nil,
		.r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, indexSet);
}

- (bool)containsIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	/* An empty range spans no indexes, so it is never contained even when its location lands in a run. */
	if (range.length == 0)
		return false;

	bool isContained = false;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, range.location, &isContained);

	if (isContained == false)
		return false;

	/* Member ranges are non-adjacent, so a contiguous range fits only if it stays inside this one. */
	return NSRangeMax(range) <= NSRangeMax(_ranges[slot]);
}

- (bool)intersectsIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	if (range.length == 0)
		return false;

	bool isContained = false;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, range.location, &isContained);

	if (isContained)
		return true;

	/* range.location lies in a gap; the next range intersects only if it starts before range ends. */
	return slot < _rangeCount && _ranges[slot].location < NSRangeMax(range);
}

- (NSUInteger)indexGreaterThanIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	bool isContained = false;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, anIndex, &isContained);

	if (isContained) {
		/* Step within the current run if possible, otherwise to the start of the next run. */
		if (anIndex + 1 < NSRangeMax(_ranges[slot]))
			return anIndex + 1;

		if (slot + 1 < _rangeCount)
			return _ranges[slot + 1].location;

		return NSNotFound;
	}

	return slot < _rangeCount ? _ranges[slot].location : NSNotFound;
}

- (NSUInteger)indexLessThanIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	bool isContained = false;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, anIndex, &isContained);

	if (isContained) {
		/* Step within the current run if possible, otherwise to the end of the previous run. */
		if (anIndex > _ranges[slot].location)
			return anIndex - 1;

		if (slot > 0)
			return NSRangeMax(_ranges[slot - 1]) - 1;

		return NSNotFound;
	}

	return slot > 0 ? NSRangeMax(_ranges[slot - 1]) - 1 : NSNotFound;
}

- (NSUInteger)indexGreaterThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	bool isContained = false;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, anIndex, &isContained);

	if (isContained)
		return anIndex;

	return slot < _rangeCount ? _ranges[slot].location : NSNotFound;
}

- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	bool isContained = false;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, anIndex, &isContained);

	if (isContained)
		return anIndex;

	return slot > 0 ? NSRangeMax(_ranges[slot - 1]) - 1 : NSNotFound;
}

- (NSUInteger)countOfIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	if (range.length == 0)
		return 0;

	NSUInteger total = 0;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, range.location, (bool[]){ false });

	/* Add the intersecting span of each run from the first candidate up to the search range's end. */
	for (NSUInteger r = slot; r < _rangeCount && _ranges[r].location < NSRangeMax(range); ++r)
		total += NSRangeIntersection(_ranges[r], range).length;

	return total;
}

- (NSUInteger)indexPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), NSEnumerationNoOptions, predicate);
}

- (NSUInteger)indexWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), options, predicate);
}

- (NSUInteger)indexInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, range, options, predicate);
}

- (NSIndexSet *)indexesPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexesInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = self, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), NSEnumerationNoOptions, predicate);
}

- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexesInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = self, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), options, predicate);
}

- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexesInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = self, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, range, options, predicate);
}

- (void)enumerateIndexesUsingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	_NSIndexSetEnumerateIndexesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), NSEnumerationNoOptions, block);
}

- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSIndexSetEnumerateIndexesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), options, block);
}

- (void)enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSIndexSetEnumerateIndexesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, range, options, block);
}

- (void)enumerateRangesUsingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSRequireNonnil(block);

	_NSIndexSetEnumerateRangesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), NSEnumerationNoOptions, block);
}

- (void)enumerateRangesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSIndexSetEnumerateRangesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), options, block);
}

- (void)enumerateRangesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSIndexSetEnumerateRangesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, range, options, block);
}

- (NSUInteger)hash
{
	NSUInteger h = OSAtomicLoad(&_hash, OSAtomicMemoryOrderRelaxed);

	if (h == 0) {
		h = NSSipHash(_ranges, _rangeCount * sizeof(NSRange), _NSIndexSetHashKey);
		OSAtomicStore(&_hash, h, OSAtomicMemoryOrderRelaxed);
	}

	return h;
}

- (bool)isEqualToIndexSet:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	if ((uintptr_t)self == (uintptr_t)indexSet)
		return true;

	Class const c = object_getClass(indexSet);

	if (c == _NSInlineIndexSetClass || c == _NSMutableInlineIndexSetClass) {
		NSInlineIndexSetLayout const *const layout = (__bridge NSInlineIndexSetLayout *)indexSet;

		if (_count != layout->count || _rangeCount != layout->rangeCount)
			return false;

		return memcmp(layout->ranges, _ranges, _rangeCount * sizeof(NSRange)) == 0;
	}

	return false;
}

- (void)dealloc
{
	free((void *)(uintptr_t)_ranges);
}

@end

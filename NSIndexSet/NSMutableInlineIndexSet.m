
#import <FoundationPrivate/NSIndexSet/NSIndexSet.h>

@interface NSMutableInlineIndexSet ()

- (void)_ensureCapacity:(NSUInteger)needed OBJC_DIRECT;

@end

@implementation NSMutableInlineIndexSet {
	NSRange *_ranges;
	/* Nonempty, non-adjacent ranges bound this to at most (NSNotFound + 1) / 2. */
	NSUInteger _rangeCount;
	NSUInteger _count;
	NSUInteger _capacity;
	NSUInteger _Atomic _hash;
}

- (instancetype)_initWithIndex:(NSUInteger)index OBJC_DIRECT
{
	return [self _initWithIndexRanges:(NSRange[]){ NSRangeMake(index, 1) } rangeCount:1 count:1];
}

- (instancetype)_initWithIndexesInRange:(NSRange)range OBJC_DIRECT
{
	return [self _initWithIndexRanges:(NSRange[]){ range } rangeCount:1 count:range.length];
}

- (instancetype)_initWithIndexRanges:(nullable const NSRange *)ranges rangeCount:(NSUInteger)rangeCount
		count:(NSUInteger)count OBJC_DIRECT
{
	if (rangeCount == 0)
		return self;

	NSUInteger const byteCount = rangeCount * sizeof(NSRange);
	_ranges = _NSMalloc(byteCount);

	memcpy(_ranges, ranges, byteCount);
	_rangeCount = rangeCount;
	_count = count;
	_capacity = rangeCount;

	return self;
}

- (id)copy
{
	if (_count == 0)
		return (NSIndexSet *)_NSZeroIndexSetInstance;

	if (_rangeCount == 1) {
		if (_ranges[0].length == 1)
			return [[NSSingleEntryIndexSet alloc] _initWithIndex:_ranges[0].location];

		return [[NSSingleRangeIndexSet alloc] _initWithIndexesInRange:_ranges[0]];
	}

	return [[NSInlineIndexSet alloc] _initWithIndexRanges:_ranges rangeCount:_rangeCount count:_count];
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
	return _count == 0 ? NSNotFound : _ranges[0].location;
}

- (NSUInteger)lastIndex
{
	return _count == 0 ? NSNotFound : NSRangeMax(_ranges[_rangeCount - 1]) - 1;
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

	if (_count == 0)
		return false;

	if (_rangeCount == 1)
		return anIndex >= _ranges[0].location && anIndex < NSRangeMax(_ranges[0]);

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

	if (_count == 0 || range.length == 0)
		return false;

	if (_rangeCount == 1)
		return range.location >= _ranges[0].location && NSRangeMax(range) <= NSRangeMax(_ranges[0]);

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

	if (_count == 0 || range.length == 0)
		return false;

	if (_rangeCount == 1)
		return NSRangeIntersection(_ranges[0], range).length != 0;

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

	if (_count == 0)
		return NSNotFound;

	if (_rangeCount == 1) {
		if (anIndex < _ranges[0].location)
			return _ranges[0].location;
		if (anIndex < NSRangeMax(_ranges[0]) - 1)
			return anIndex + 1;
		return NSNotFound;
	}

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

	if (_count == 0)
		return NSNotFound;

	if (_rangeCount == 1) {
		if (anIndex > NSRangeMax(_ranges[0]) - 1)
			return NSRangeMax(_ranges[0]) - 1;
		if (anIndex > _ranges[0].location)
			return anIndex - 1;
		return NSNotFound;
	}

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

	if (_count == 0)
		return NSNotFound;

	if (_rangeCount == 1) {
		if (anIndex < _ranges[0].location)
			return _ranges[0].location;
		return anIndex < NSRangeMax(_ranges[0]) ? anIndex : NSNotFound;
	}

	bool isContained = false;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, anIndex, &isContained);

	if (isContained)
		return anIndex;

	return slot < _rangeCount ? _ranges[slot].location : NSNotFound;
}

- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	if (_count == 0)
		return NSNotFound;

	if (_rangeCount == 1) {
		if (anIndex > NSRangeMax(_ranges[0]) - 1)
			return NSRangeMax(_ranges[0]) - 1;
		return anIndex >= _ranges[0].location ? anIndex : NSNotFound;
	}

	bool isContained = false;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, anIndex, &isContained);

	if (isContained)
		return anIndex;

	return slot > 0 ? NSRangeMax(_ranges[slot - 1]) - 1 : NSNotFound;
}

- (NSUInteger)countOfIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	if (_count == 0 || range.length == 0)
		return 0;

	if (_rangeCount == 1)
		return NSRangeIntersection(_ranges[0], range).length;

	NSUInteger total = 0;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, range.location, (bool[]){ false });

	for (NSUInteger r = slot; r < _rangeCount && _ranges[r].location < NSRangeMax(range); ++r)
		total += NSRangeIntersection(_ranges[r], range).length;

	return total;
}

- (NSUInteger)indexPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	if (_count == 0)
		return NSNotFound;

	return _NSIndexSetIndexInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), NSEnumerationNoOptions, predicate);
}

- (NSUInteger)indexWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	if (_count == 0)
		return NSNotFound;

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

	if (_count == 0)
		return NSNotFound;

	return _NSIndexSetIndexInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, range, options, predicate);
}

- (NSIndexSet *)indexesPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	if (_count == 0)
		return (NSIndexSet *)_NSZeroIndexSetInstance;

	return _NSIndexSetIndexesInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = self, .indexSetCls = _NSMutableInlineIndexSetClass, .r.ranges = _ranges,
		.rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), NSEnumerationNoOptions, predicate);
}

- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	if (_count == 0)
		return (NSIndexSet *)_NSZeroIndexSetInstance;

	return _NSIndexSetIndexesInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = self, .indexSetCls = _NSMutableInlineIndexSetClass, .r.ranges = _ranges,
		.rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), options, predicate);
}

- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	if (_count == 0)
		return (NSIndexSet *)_NSZeroIndexSetInstance;

	return _NSIndexSetIndexesInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = self, .indexSetCls = _NSMutableInlineIndexSetClass, .r.ranges = _ranges,
		.rangeCount = _rangeCount, .count = _count
	}, range, options, predicate);
}

- (void)enumerateIndexesUsingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	if (_count == 0)
		return;

	_NSIndexSetEnumerateIndexesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), NSEnumerationNoOptions, block);
}

- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	if (_count == 0)
		return;

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

	if (_count == 0)
		return;

	_NSIndexSetEnumerateIndexesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, range, options, block);
}

- (void)enumerateRangesUsingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSRequireNonnil(block);

	if (_count == 0)
		return;

	_NSIndexSetEnumerateRangesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, NSRangeMake(0, NSRangeMax(_ranges[_rangeCount - 1])), NSEnumerationNoOptions, block);
}

- (void)enumerateRangesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	if (_count == 0)
		return;

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

	if (_count == 0)
		return;

	_NSIndexSetEnumerateRangesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = _ranges, .rangeCount = _rangeCount, .count = _count
	}, range, options, block);
}

- (NSUInteger)hash
{
	if (_count == 0)
		return _NSZeroIndexSetHash;

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

	if (_count == 0)
		return c == _NSZeroIndexSetClass ||
			(c == _NSMutableInlineIndexSetClass &&
			((__bridge NSInlineIndexSetLayout *)indexSet)->count == 0);

	if (c == _NSSingleEntryIndexSetClass)
		return _count == 1 && _ranges[0].location ==
			((__bridge NSSingleEntryIndexSetLayout *)indexSet)->index;

	if (c == _NSSingleRangeIndexSetClass)
		return _rangeCount == 1 && NSRangeEqualToRange(_ranges[0],
			((__bridge NSSingleRangeIndexSetLayout *)indexSet)->range);

	if (c == _NSInlineIndexSetClass || c == _NSMutableInlineIndexSetClass) {
		NSInlineIndexSetLayout const *const layout = (__bridge NSInlineIndexSetLayout *)indexSet;

		if (_count != layout->count || _rangeCount != layout->rangeCount)
			return false;

		return memcmp(_ranges, layout->ranges, _rangeCount * sizeof(NSRange)) == 0;
	}

	return false;
}

#pragma mark - Mutators

/*
 * Grow only the range-slot allocation; callers update the logical range and index counts after this succeeds.
 * Capacity doubles geometrically until doubling would exceed the largest NSRange allocation, at which point it
 * grows exactly to the requested size.
 */
- (void)_ensureCapacity:(NSUInteger)needed OBJC_DIRECT
{
	NSUInteger const maximumCapacity = NSUIntegerMax / sizeof(NSRange);
	void *grown;

	if (_capacity >= needed)
		return;

	if (needed > maximumCapacity)
		_NSRaiseException(MethodContext, NSMallocException, @"new capacity exceeds maximum capacity.");

	NSUInteger newCapacity = _capacity == 0 ? 4 : _capacity;

	while (newCapacity < needed) {
		if (newCapacity > maximumCapacity / 2) {
			newCapacity = needed;
			break;
		}

		newCapacity *= 2;
	}

	if ((grown = realloc(_ranges, newCapacity * sizeof(NSRange))) == nullptr)
		_NSRaiseException(MethodContext, NSMallocException, @"realloc returned nullptr.");

	_ranges = grown;
	_capacity = newCapacity;
}

- (void)addIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	/* The search returns either the containing run or the gap slot where a new run would be inserted. */
	bool isContained = false;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, anIndex, &isContained);

	if (isContained)
		return;

	bool const joinsLeft = slot > 0 && NSRangeMax(_ranges[slot - 1]) == anIndex;
	bool const joinsRight = slot < _rangeCount && _ranges[slot].location == anIndex + 1;

	/* Adding one index can bridge two runs, extend either neighbour, or require a new singleton run. */
	if (joinsLeft && joinsRight) {
		_ranges[slot - 1].length = NSRangeMax(_ranges[slot]) - _ranges[slot - 1].location;
		memmove(&_ranges[slot], &_ranges[slot + 1], (_rangeCount - slot - 1) * sizeof(NSRange));
		--_rangeCount;
	} else if (joinsLeft) {
		++_ranges[slot - 1].length;
	} else if (joinsRight) {
		--_ranges[slot].location;
		++_ranges[slot].length;
	} else {
		[self _ensureCapacity:_rangeCount + 1];
		memmove(&_ranges[slot + 1], &_ranges[slot], (_rangeCount - slot) * sizeof(NSRange));
		_ranges[slot] = NSRangeMake(anIndex, 1);
		++_rangeCount;
	}

	++_count;
	OSAtomicStore(&_hash, 0, OSAtomicMemoryOrderRelaxed);
}

/* Remove one member, deleting, clipping, or splitting its containing run as required. */
- (void)removeIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	if (_count == 0)
		return;

	bool isContained = false;
	NSUInteger const slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, anIndex, &isContained);

	if (isContained == false)
		return;

	NSRange const range = _ranges[slot];
	NSUInteger const rangeEnd = NSRangeMax(range);

	/* A middle removal is the only case that can increase the number of runs. */
	if (range.length == 1) {
		memmove(&_ranges[slot], &_ranges[slot + 1], (_rangeCount - slot - 1) * sizeof(NSRange));
		--_rangeCount;
	} else if (anIndex == range.location) {
		++_ranges[slot].location;
		--_ranges[slot].length;
	} else if (anIndex + 1 == rangeEnd) {
		--_ranges[slot].length;
	} else {
		[self _ensureCapacity:_rangeCount + 1];
		memmove(&_ranges[slot + 2], &_ranges[slot + 1], (_rangeCount - slot - 1) * sizeof(NSRange));
		_ranges[slot].length = anIndex - range.location;
		_ranges[slot + 1] = NSRangeMake(anIndex + 1, rangeEnd - (anIndex + 1));
		++_rangeCount;
	}

	--_count;
	OSAtomicStore(&_hash, 0, OSAtomicMemoryOrderRelaxed);
}

/*
 * Insert a range and coalesce every overlapping or adjacent run into one. The representation invariant is a sorted
 * list of disjoint, non-adjacent, non-empty ranges, so there is at most one contiguous interval of affected slots.
 */
- (void)addIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	if (range.length == 0)
		return;

	NSUInteger const rangeEnd = NSRangeMax(range);
	NSUInteger lo;
	NSUInteger end;
	NSUInteger a = 0;
	NSUInteger b = _rangeCount;

	/* Find the first run that overlaps the input or touches its left edge. */
	while (a < b) {
		NSUInteger const mid = a + (b - a) / 2;

		if (NSRangeMax(_ranges[mid]) < range.location)
			a = mid + 1;
		else
			b = mid;
	}

	lo = a;

	/* [lo, end) is now exactly the set of runs that the input overlaps or joins. */
	end = lo;
	while (end < _rangeCount && _ranges[end].location <= rangeEnd)
		++end;

	if (end == lo) {
		/* The range lies wholly within a gap, so insert it without touching either neighbour. */
		[self _ensureCapacity:_rangeCount + 1];
		memmove(&_ranges[lo + 1], &_ranges[lo], (_rangeCount - lo) * sizeof(NSRange));
		_ranges[lo] = range;
		++_rangeCount;
		_count += range.length;
		OSAtomicStore(&_hash, 0, OSAtomicMemoryOrderRelaxed);
		return;
	}

	NSUInteger const newLocation = MIN(range.location, _ranges[lo].location);
	NSUInteger const newEnd = MAX(rangeEnd, NSRangeMax(_ranges[end - 1]));
	NSRange const merged = NSRangeMake(newLocation, newEnd - newLocation);

	/* A range already contained by one run is a true no-op, including for the cached hash. */
	if (end == lo + 1 && NSRangeEqualToRange(merged, _ranges[lo]))
		return;

	NSUInteger removedLength = 0;
	for (NSUInteger i = lo; i < end; ++i)
		removedLength += _ranges[i].length;

	_ranges[lo] = merged;

	if (end > lo + 1) {
		/* The first affected slot holds the union; close the slots consumed by the remaining runs. */
		memmove(&_ranges[lo + 1], &_ranges[end], (_rangeCount - end) * sizeof(NSRange));
		_rangeCount -= end - lo - 1;
	}

	_count += merged.length - removedLength;
	OSAtomicStore(&_hash, 0, OSAtomicMemoryOrderRelaxed);
}

/*
 * Delete every member in a range. Any number of complete runs may disappear, but only the first and last affected
 * runs can leave remnants, so the replacement is completely described by at most two ranges.
 */
- (void)removeIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	if (_count == 0 || range.length == 0)
		return;

	NSUInteger const rangeEnd = NSRangeMax(range);
	NSUInteger lo;
	NSUInteger end;
	NSUInteger a = 0;
	NSUInteger b = _rangeCount;

	/* Find the first run extending strictly past range.location. */
	while (a < b) {
		NSUInteger const mid = a + (b - a) / 2;

		if (NSRangeMax(_ranges[mid]) <= range.location)
			a = mid + 1;
		else
			b = mid;
	}
	lo = a;

	end = lo;
	while (end < _rangeCount && _ranges[end].location < rangeEnd)
		++end;

	if (lo == end)
		return;

	NSRange remnants[2];
	NSUInteger remnantCount = 0;
	NSUInteger const removedRangeCount = end - lo;
	NSUInteger removed = 0;

	for (NSUInteger i = lo; i < end; ++i)
		removed += NSRangeIntersection(_ranges[i], range).length;

	/* Preserve the portions of the boundary runs that lie outside the removal interval. */
	if (_ranges[lo].location < range.location)
		remnants[remnantCount++] = NSRangeMake(_ranges[lo].location, range.location - _ranges[lo].location);

	if (NSRangeMax(_ranges[end - 1]) > rangeEnd)
		remnants[remnantCount++] = NSRangeMake(rangeEnd, NSRangeMax(_ranges[end - 1]) - rangeEnd);

	/* Replace [lo, end) with the remnants, moving the untouched suffix in the necessary direction. */
	if (remnantCount > removedRangeCount) {
		[self _ensureCapacity:_rangeCount + (remnantCount - removedRangeCount)];
		memmove(&_ranges[end + (remnantCount - removedRangeCount)], &_ranges[end],
			(_rangeCount - end) * sizeof(NSRange));
		_rangeCount += remnantCount - removedRangeCount;
	} else if (remnantCount < removedRangeCount) {
		memmove(&_ranges[end - (removedRangeCount - remnantCount)], &_ranges[end],
			(_rangeCount - end) * sizeof(NSRange));
		_rangeCount -= removedRangeCount - remnantCount;
	}

	for (NSUInteger i = 0; i < remnantCount; ++i)
		_ranges[lo + i] = remnants[i];

	_count -= removed;
	OSAtomicStore(&_hash, 0, OSAtomicMemoryOrderRelaxed);
}

- (void)addIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	if ((uintptr_t)self == (uintptr_t)indexSet)
		return;

	NSIndexSetRepresentation const rep = _NSIndexSetGetRepresentation(indexSet);

	if (rep.rangeCount == 0)
		return;

	if (rep.rangeCount == 1) {
		[self addIndexesInRange:rep.r.range];
		return;
	}

	for (NSUInteger i = 0; i < rep.rangeCount; ++i)
		[self addIndexesInRange:rep.r.ranges[i]];
}

- (void)removeIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	if ((uintptr_t)self == (uintptr_t)indexSet) {
		[self removeAllIndexes];
		return;
	}

	if (_count == 0)
		return;

	NSIndexSetRepresentation const rep = _NSIndexSetGetRepresentation(indexSet);

	if (rep.rangeCount == 0)
		return;

	if (rep.rangeCount == 1) {
		[self removeIndexesInRange:rep.r.range];
		return;
	}

	for (NSUInteger i = 0; i < rep.rangeCount && _count != 0; ++i)
		[self removeIndexesInRange:rep.r.ranges[i]];
}

/* Keep the allocation for reuse; only the active prefix and its derived state become empty. */
- (void)removeAllIndexes
{
	if (_count == 0)
		return;

	_rangeCount = 0;
	_count = 0;
	OSAtomicStore(&_hash, 0, OSAtomicMemoryOrderRelaxed);
}

- (void)shiftIndexesStartingAtIndex:(NSUInteger)anIndex by:(NSInteger)delta
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	if (delta == 0 || _count == 0)
		return;

	if (delta > 0) {
		NSUInteger const distance = (NSUInteger)delta;
		NSUInteger const topIndex = NSRangeMax(_ranges[_rangeCount - 1]) - 1;
		bool isContained = false;

		if (anIndex > topIndex)
			return;

		/* Validate the highest result before splitting a run or changing any location. */
		if (distance > NSIndexSetMaximumIndex - topIndex)
			_NSRaiseException(MethodContext, NSRangeException, @"shift overflows the index space.");

		NSUInteger slot = _NSIndexSetRangeSlotForIndex(_ranges, _rangeCount, anIndex, &isContained);

		if (isContained && _ranges[slot].location < anIndex) {
			NSRange const whole = _ranges[slot];

			/* Split a straddling run so every run from slot onward moves in its entirety. */
			[self _ensureCapacity:_rangeCount + 1];
			memmove(&_ranges[slot + 1], &_ranges[slot], (_rangeCount - slot) * sizeof(NSRange));
			_ranges[slot] = NSRangeMake(whole.location, anIndex - whole.location);
			_ranges[slot + 1] = NSRangeMake(anIndex, NSRangeMax(whole) - anIndex);
			++_rangeCount;
			++slot;
		}

		for (NSUInteger i = slot; i < _rangeCount; ++i)
			_ranges[i].location += distance;

		OSAtomicStore(&_hash, 0, OSAtomicMemoryOrderRelaxed);
		return;
	}

	/* Compute the magnitude without negating NSIntegerMin. */
	NSUInteger const distance = (NSUInteger)(-(delta + 1)) + 1;

	if (distance > NSIndexSetMaximumIndex) {
		[self removeAllIndexes];
		return;
	}

	/*
	 * A downward shift first clears the destination corridor, then slides everything at shiftFrom or above. When
	 * anIndex is smaller than the magnitude, shiftFrom is raised to distance so no subtraction can underflow.
	 */
	NSUInteger const shiftFrom = MAX(anIndex, distance);
	[self removeIndexesInRange:NSRangeMake(shiftFrom - distance, distance)];

	NSUInteger a = 0;
	NSUInteger b = _rangeCount;

	while (a < b) {
		NSUInteger const mid = a + (b - a) / 2;

		if (_ranges[mid].location < shiftFrom)
			a = mid + 1;
		else
			b = mid;
	}

	NSUInteger const slot = a;

	if (slot == _rangeCount)
		return;

	for (NSUInteger i = slot; i < _rangeCount; ++i)
		_ranges[i].location -= distance;

	/* The moved suffix can land flush against the stationary prefix; only this boundary can need coalescing. */
	if (slot > 0 && NSRangeMax(_ranges[slot - 1]) == _ranges[slot].location) {
		_ranges[slot - 1].length += _ranges[slot].length;
		memmove(&_ranges[slot], &_ranges[slot + 1], (_rangeCount - slot - 1) * sizeof(NSRange));
		--_rangeCount;
	}

	OSAtomicStore(&_hash, 0, OSAtomicMemoryOrderRelaxed);
}

- (void)dealloc
{
	free(_ranges);
}

@end

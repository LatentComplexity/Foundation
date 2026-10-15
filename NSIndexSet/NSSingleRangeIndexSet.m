
#import <FoundationPrivate/NSIndexSet/NSIndexSet.h>

@implementation NSSingleRangeIndexSet {
	NSRange _range;
}

- (instancetype)_initWithIndexesInRange:(NSRange)range OBJC_DIRECT
{
	_range = range;

	return self;
}

- (id)copy
{
	return self;
}

- (id)mutableCopy
{
	return [[NSMutableInlineIndexSet alloc] _initWithIndexesInRange:_range];
}

- (NSUInteger)count
{
	return _range.length;
}

- (NSUInteger)firstIndex
{
	return _range.location;
}

- (NSUInteger)lastIndex
{
	return _range.location + _range.length - 1;
}

- (NSUInteger)getIndexes:(NSUInteger *)indexBuffer maxCount:(NSUInteger)bufferSize
		inIndexRange:(nullable NSRange *)rangePointer
{
	_NSRequireNonnullptr(indexBuffer);

	return _NSIndexSetGetIndexesInRange(((NSIndexSetRepresentation) { .indexSet = nil, .indexSetCls = Nil,
		.r.ranges = &_range, .rangeCount = 1, .count = _range.length
	}), indexBuffer, bufferSize, rangePointer);
}

- (bool)containsIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	return anIndex >= _range.location && anIndex < NSRangeMax(_range);
}

- (bool)containsIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	if ((uintptr_t)self == (uintptr_t)indexSet)
		return true;

	return _NSIndexSetContainsIndexes((NSIndexSetRepresentation) { .indexSet = nil, .indexSetCls = Nil,
		.r.ranges = &_range, .rangeCount = 1, .count = _range.length
	}, indexSet);
}

- (bool)containsIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	if (range.length == 0)
		return false;

	return NSRangeEqualToRange(NSRangeUnion(_range, range), _range);
}

- (bool)intersectsIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	return NSRangeIntersection(_range, range).length != 0;
}

- (NSUInteger)indexGreaterThanIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	if (anIndex < _range.location)
		return _range.location;

	if (anIndex < NSRangeMax(_range) - 1)
		return anIndex + 1;

	return NSNotFound;
}

- (NSUInteger)indexLessThanIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	if (anIndex > NSRangeMax(_range) - 1)
		return NSRangeMax(_range) - 1;

	if (anIndex > _range.location)
		return anIndex - 1;

	return NSNotFound;
}

- (NSUInteger)indexGreaterThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	/* anIndex itself qualifies inside the range; only step up to firstIndex from below it. */
	if (anIndex < _range.location)
		return _range.location;

	if (anIndex <= NSRangeMax(_range) - 1)
		return anIndex;

	return NSNotFound;
}

- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRequireIndexBelowMaximum(anIndex);

	/* anIndex itself qualifies inside the range; only step down to lastIndex from above it. */
	if (anIndex > NSRangeMax(_range) - 1)
		return NSRangeMax(_range) - 1;

	if (anIndex >= _range.location)
		return anIndex;

	return NSNotFound;
}

- (NSUInteger)countOfIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	return NSRangeIntersection(_range, range).length;
}

- (NSUInteger)indexPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = &_range, .rangeCount = 1,
		.count = _range.length
	}, _range, NSEnumerationNoOptions, predicate);
}

- (NSUInteger)indexWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = &_range, .rangeCount = 1,
		.count = _range.length
	}, _range, options, predicate);
}

- (NSUInteger)indexInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = &_range, .rangeCount = 1,
		.count = _range.length
	}, range, options, predicate);
}

- (NSIndexSet *)indexesPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexesInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = self, .indexSetCls = Nil, .r.ranges = &_range, .rangeCount = 1,
		.count = _range.length
	}, _range, NSEnumerationNoOptions, predicate);
}

- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexesInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = self, .indexSetCls = Nil, .r.ranges = &_range, .rangeCount = 1,
		.count = _range.length
	}, _range, options, predicate);
}

- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSIndexSetIndexesInRangeWithOptionsPassingTest((NSIndexSetRepresentation) {
		.indexSet = self, .indexSetCls = Nil, .r.ranges = &_range, .rangeCount = 1,
		.count = _range.length
	}, range, options, predicate);
}

- (void)enumerateIndexesUsingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	_NSIndexSetEnumerateIndexesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = &_range, .rangeCount = 1,
		.count = _range.length
	}, _range, NSEnumerationNoOptions, block);
}

- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSIndexSetEnumerateIndexesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = &_range, .rangeCount = 1,
		.count = _range.length
	}, _range, options, block);
}

- (void)enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSIndexSetEnumerateIndexesInRangeWithOptionsUsingBlock((NSIndexSetRepresentation) {
		.indexSet = nil, .indexSetCls = Nil, .r.ranges = &_range, .rangeCount = 1,
		.count = _range.length
	}, range, options, block);
}

- (void)enumerateRangesUsingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSRequireNonnil(block);

	block(_range, (bool[]){ false });
}

- (void)enumerateRangesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	block(_range, (bool[]){ false });
}

- (void)enumerateRangesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	NSRange const section = NSRangeIntersection(_range, range);

	if (section.length != 0)
		block(section, (bool[]){ false });
}

- (NSUInteger)hash
{
	return NSSipHash(&_range, sizeof(NSRange), _NSIndexSetHashKey);
}

- (bool)isEqualToIndexSet:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	if ((uintptr_t)self == (uintptr_t)indexSet)
		return true;

	Class const c = object_getClass(indexSet);

	if (c == _NSSingleRangeIndexSetClass) {
		NSRange const range = ((__bridge NSSingleRangeIndexSetLayout *)indexSet)->range;
		return NSRangeEqualToRange(_range, range);
	}

	if (c == _NSMutableInlineIndexSetClass) {
		NSInlineIndexSetLayout const *const layout = (__bridge NSInlineIndexSetLayout *)indexSet;
		return layout->rangeCount == 1 && NSRangeEqualToRange(_range, layout->ranges[0]);
	}

	return false;
}

@end

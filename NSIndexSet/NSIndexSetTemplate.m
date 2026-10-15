
#import <FoundationPrivate/NSIndexSet/NSIndexSet.h>

@implementation NSIndexSetTemplate

- (instancetype)init
{
	return (id)_NSZeroIndexSetInstance;
}

- (instancetype)initWithIndexSet:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	return [indexSet copy];
}

- (instancetype)initWithIndex:(NSUInteger)index
{
	_NSIndexSetRequireIndexBelowMaximum(index);

	return (id)[[NSSingleEntryIndexSet alloc] _initWithIndex:index];
}

- (instancetype)initWithIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	if (range.length == 0)
		return (id)_NSZeroIndexSetInstance;

	if (range.length == 1)
		return (id)[[NSSingleEntryIndexSet alloc] _initWithIndex:range.location];

	return (id)[[NSSingleRangeIndexSet alloc] _initWithIndexesInRange:range];
}

@end

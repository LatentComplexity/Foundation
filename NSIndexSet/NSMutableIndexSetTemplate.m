
#import <FoundationPrivate/NSIndexSet/NSIndexSet.h>

@implementation NSMutableIndexSetTemplate

- (instancetype)init
{
	return (id)[[NSMutableInlineIndexSet alloc] _initWithIndexRanges:nullptr rangeCount:0 count:0];
}

- (instancetype)initWithIndexSet:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	return [indexSet mutableCopy];
}

- (instancetype)initWithIndex:(NSUInteger)index
{
	_NSIndexSetRequireIndexBelowMaximum(index);

	return (id)[[NSMutableInlineIndexSet alloc] _initWithIndex:index];
}

- (instancetype)initWithIndexesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)NSNotFound);

	if (range.length == 0)
		return (id)[[NSMutableInlineIndexSet alloc] _initWithIndexRanges:nullptr rangeCount:0 count:0];

	return (id)[[NSMutableInlineIndexSet alloc] _initWithIndexesInRange:range];
}

@end

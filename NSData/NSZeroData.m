
#import <FoundationPrivate/NSData/NSData.h>

@implementation NSZeroData

- (id)copy
{
	return self;
}

- (id)mutableCopy
{
	return (id)[[NSMutableInlineData alloc] _initWithBytes:nullptr count:0];
}

- (void const *)bytes
{
	return nullptr;
}

- (NSUInteger)count
{
	return 0;
}

- (NSData *)subdataWithRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)0);

	return _NSZeroDataInstance;
}

- (void)getBytes:(void *)buffer count:(NSUInteger)length
{
	_NSRequireNonnullptr(buffer);
}

- (void)getBytes:(void *)buffer range:(NSRange)range
{
	_NSRequireNonnullptr(buffer);
	_NSRangeWithinUpperBound(range, (NSUInteger)0);
}

- (void)enumerateByteRangesUsingBlock:(void (NS_NOESCAPE ^)(void const *, NSRange, bool *))block
{
	_NSRequireNonnil(block);

	block(nullptr, NSRangeMake(0, 0), (bool[]){ false });
}

- (NSRange)rangeOfData:(NSData *)dataToFind options:(NSDataSearchOptions)searchOptions range:(NSRange)searchRange
{
	_NSRequireNonnil(dataToFind);
	_NSDataSearchOptionsCheck(searchOptions);
	_NSRangeWithinUpperBound(searchRange, (NSUInteger)0);

	if (dataToFind.count == 0)
		return NSRangeMake(0, 0);

	return NSRangeMake(NSNotFound, 0);
}

- (NSUInteger)hash
{
	return _NSZeroDataHash;
}

- (bool)isEqualToData:(NSData *)otherData
{
	_NSRequireNonnil(otherData);

	if ((uintptr_t)self == (uintptr_t)otherData)
		return true;

	Class const c = object_getClass(otherData);

	if (c == _NSInlineDataClass || c == _NSSubrangeDataClass)
		return false;

	if (c == _NSMutableInlineDataClass)
		return ((__bridge NSMutableInlineDataLayout *)otherData)->buffer->count == 0;

	if (c == _NSZeroDataClass)
		return true;

	/* All instances, no matter their class, are logically equal if they have a count of zero. */
	if (otherData.count == 0)
		return true;

	return false;
}

@end

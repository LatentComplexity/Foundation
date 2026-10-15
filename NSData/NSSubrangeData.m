
#import <FoundationPrivate/NSData/NSData.h>

@implementation NSSubrangeData {
	NSDataBuffer *_buffer;
	NSUInteger _base;
	NSUInteger _count;
	NSUInteger _Atomic _hash;
}

- (id)copy
{
	return self;
}

- (id)mutableCopy
{
	/* This here is optimization work for "future me". */
	return [[NSMutableInlineData alloc] _initWithBytes:_buffer->bytes + _base count:_count];
}

- (instancetype)_initWithBuffer:(NSDataBuffer *)buffer base:(NSUInteger)base count:(NSUInteger)count OBJC_DIRECT
{
	_buffer = NSDataBufferRetain(buffer);
	_base = base;
	_count = count;

	return self;
}

- (void const *)bytes
{
	return _buffer->bytes + _base;
}

- (NSUInteger)count
{
	return _count;
}

- (NSData *)subdataWithRange:(NSRange)range
{
	if (range.location == 0 && range.length == _count)
		return self;

	_NSRangeWithinUpperBound(range, _count);

	if (range.length == 0)
		return (id)_NSZeroDataInstance;

	/* Flatten a sub-window of a window onto the same buffer. */
	return [[NSSubrangeData alloc] _initWithBuffer:_buffer base:_base + range.location count:range.length];
}

- (void)getBytes:(void *)buffer count:(NSUInteger)count
{
	_NSRequireNonnullptr(buffer);

	memcpy(buffer, _buffer->bytes + _base, MIN(count, _count));
}

- (void)getBytes:(void *)buffer range:(NSRange)range
{
	_NSRequireNonnullptr(buffer);
	_NSRangeWithinUpperBound(range, _count);

	if (range.length == 0)
		return;

	memcpy(buffer, _buffer->bytes + _base + range.location, range.length);
}

- (void)enumerateByteRangesUsingBlock:(void (NS_NOESCAPE ^)(void const *, NSRange, bool *))block
{
	_NSRequireNonnil(block);

	block(_buffer->bytes + _base, NSRangeMake(0, _count), (bool[]){ false });
}

- (NSUInteger)hash
{
	NSUInteger h = OSAtomicLoad(&_hash, OSAtomicMemoryOrderRelaxed);

	if (h == 0) {
		NSSipHashContext c;

		NSSipHashContextInit(&c, _NSDataHashKey);
		NSSipHashWithContext(&c, (NSUInteger[]){ _count }, sizeof(NSUInteger));
		NSSipHashWithContext(&c, _buffer->bytes + _base, _count);
		NSSipHashWithContextFinalize(&c, &h);
		OSAtomicStore(&_hash, h, OSAtomicMemoryOrderRelaxed);
	}

	return h;
}

- (void)dealloc
{
	NSDataBufferRelease(_buffer);
}

@end

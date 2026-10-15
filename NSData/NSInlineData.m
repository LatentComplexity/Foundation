
#import <FoundationPrivate/NSData/NSData.h>

@implementation NSInlineData {
	NSDataBuffer *_buffer;
}

- (id)copy
{
	return self;
}

- (id)mutableCopy
{
	return [[NSMutableInlineData alloc] _initWithBuffer:_buffer];
}

- (instancetype)_initAdoptingBuffer:(NSDataBuffer *)buffer OBJC_DIRECT
{
	_buffer = buffer;

	return self;
}

- (instancetype)_initWithBytes:(void const *)bytes count:(NSUInteger)count OBJC_DIRECT
{
	_buffer = NSDataBufferCreateWithBytes(bytes, count);

	return self;
}

- (instancetype)_initWithBuffer:(NSDataBuffer *)buffer OBJC_DIRECT
{
	_buffer = NSDataBufferRetain(buffer);

	return self;
}

- (void const *)bytes
{
	return _buffer->bytes;
}

- (NSUInteger)count
{
	return _buffer->count;
}

- (NSData *)subdataWithRange:(NSRange)range
{
	if (range.location == 0 && range.length == _buffer->count)
		return self;

	_NSRangeWithinUpperBound(range, _buffer->count);

	if (range.length == 0)
		return (id)_NSZeroDataInstance;

	return [[NSSubrangeData alloc] _initWithBuffer:_buffer base:range.location count:range.length];
}

- (void)getBytes:(void *)buffer count:(NSUInteger)count
{
	_NSRequireNonnullptr(buffer);

	memcpy(buffer, _buffer->bytes, MIN(count, _buffer->count));
}

- (void)getBytes:(void *)buffer range:(NSRange)range
{
	_NSRequireNonnullptr(buffer);
	_NSRangeWithinUpperBound(range, _buffer->count);

	if (range.length == 0)
		return;

	memcpy(buffer, (char const *)_buffer->bytes + range.location, range.length);
}

- (void)enumerateByteRangesUsingBlock:(void (NS_NOESCAPE ^)(void const *, NSRange, bool *))block
{
	_NSRequireNonnil(block);

	block(_buffer->bytes, NSRangeMake(0, _buffer->count), (bool[]){ false });
}

- (NSUInteger)hash
{
	NSUInteger h = OSAtomicLoad(&_buffer->hash, OSAtomicMemoryOrderRelaxed);

	if (h == 0) {
		NSSipHashContext c;

		NSSipHashContextInit(&c, _NSDataHashKey);
		NSSipHashWithContext(&c, (NSUInteger[]){ _buffer->count }, sizeof(NSUInteger));
		NSSipHashWithContext(&c, _buffer->bytes, _buffer->count);
		NSSipHashWithContextFinalize(&c, &h);
		OSAtomicStore(&_buffer->hash, h, OSAtomicMemoryOrderRelaxed);
	}

	return h;
}

- (bool)isEqualToData:(NSData *)otherData
{
	_NSRequireNonnil(otherData);

	if ((uintptr_t)self == (uintptr_t)otherData)
		return true;

	NSUInteger const count = _buffer->count;
	NSDataRepresentation const rep = _NSDataGetRepresentation(otherData);

	if (count != rep.count)
		return false;

	if (memcmp(_buffer->bytes, rep.bytes, count) == 0)
		return true;

	return false;
}

- (void)dealloc
{
	NSDataBufferRelease(_buffer);
}

@end

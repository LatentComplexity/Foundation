
#import <FoundationPrivate/NSData/NSData.h>

@implementation NSMutableDataTemplate

- (instancetype)init
{
	return (id)[[NSMutableInlineData alloc] _initWithBytes:nullptr count:0];
}

- (instancetype)initWithData:(NSData *)data
{
	_NSRequireNonnil(data);

	return [data mutableCopy];
}

- (instancetype)initWithBytes:(void const *)bytes count:(NSUInteger)count
{
	_NSRequireNonnullptr(bytes);

	return (id)[[NSMutableInlineData alloc] _initWithBytes:bytes count:count];
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count
{
	_NSRequireNonnullptr(bytes);

	if (count == 0) {
		free(bytes);
		return (id)[[NSMutableInlineData alloc] _initWithCapacity:0];
	}

	return (id)[[NSMutableInlineData alloc] _initAdoptingBuffer:NSDataBufferAdopt(bytes, count, true)];
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count freeWhenDone:(bool)freeBuffer
{
	_NSRequireNonnullptr(bytes);

	if (count == 0) {
		if (freeBuffer)
			free(bytes);

		return (id)[[NSMutableInlineData alloc] _initWithCapacity:0];
	}

	return (id)[[NSMutableInlineData alloc] _initAdoptingBuffer:NSDataBufferAdopt(bytes, count, freeBuffer)];
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count
		deallocator:(nullable void (^)(void *, NSUInteger))deallocator
{
	_NSRequireNonnullptr(bytes);

	if (count == 0) {
		if (deallocator != nil)
			deallocator(bytes, 0);

		return (id)[[NSMutableInlineData alloc] _initWithCapacity:0];
	}

	return (id)[[NSMutableInlineData alloc] _initAdoptingBuffer:NSDataBufferAdoptWithBlock(bytes, count,
		(NSDataDeallocator _Nonnull)deallocator)];
}

- (instancetype)initWithCapacity:(NSUInteger)capacity
{
	return (id)[[NSMutableInlineData alloc] _initWithCapacity:capacity];
}

- (instancetype)initWithCount:(NSUInteger)count
{
	return (id)[[NSMutableInlineData alloc] _initWithCount:count];
}

@end

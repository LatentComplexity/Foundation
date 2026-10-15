
#import <FoundationPrivate/NSData/NSData.h>

@implementation NSDataTemplate

- (instancetype)init
{
	return (id)_NSZeroDataInstance;
}

- (instancetype)initWithData:(NSData *)data
{
	_NSRequireNonnil(data);

	return [data copy];
}

- (instancetype)initWithBytes:(void const *)bytes count:(NSUInteger)count
{
	_NSRequireNonnullptr(bytes);

	if (count == 0)
		return (id)_NSZeroDataInstance;

	return (id)[[NSInlineData alloc] _initWithBytes:bytes count:count];
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count
{
	_NSRequireNonnullptr(bytes);

	if (count == 0) {
		free(bytes);
		return (id)_NSZeroDataInstance;
	}

	return (id)[[NSInlineData alloc] _initAdoptingBuffer:NSDataBufferAdopt(bytes, count, true)];
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count freeWhenDone:(bool)freeBuffer
{
	_NSRequireNonnullptr(bytes);

	if (count == 0) {
		if (freeBuffer)
			free(bytes);

		return (id)_NSZeroDataInstance;
	}

	return (id)[[NSInlineData alloc] _initAdoptingBuffer:NSDataBufferAdopt(bytes, count, freeBuffer)];
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count
		deallocator:(nullable void (^)(void *, NSUInteger))deallocator
{
	_NSRequireNonnullptr(bytes);

	if (count == 0) {
		if (deallocator != nil)
			deallocator(bytes, 0);

		return (id)_NSZeroDataInstance;
	}

	return (id)[[NSInlineData alloc] _initAdoptingBuffer:NSDataBufferAdoptWithBlock(bytes, count,
		(NSDataDeallocator _Nonnull)deallocator)];
}

@end

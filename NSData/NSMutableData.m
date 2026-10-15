
#import <FoundationPrivate/NSData/NSData.h>

@implementation NSMutableData

static NSMutableDataTemplate *_NSMutableDataTemplateInstance = nil;

+ (void)initialize
{
	static NSCallOnceState s = {};

	if (self == [NSMutableData class])
		NSCallOnce(&s, ^{
			_NSMutableDataTemplateInstance = [NSMutableDataTemplate alloc];
		});
}

+ (instancetype)alloc
{
	if (self == _NSMutableDataClass)
		return _NSMutableDataTemplateInstance;

	return class_createInstance(self, 0);
}

- (id)copy
{
	if (self.count == 0)
		return (id)_NSZeroDataInstance;

	return [[NSInlineData alloc] _initWithBytes:self.bytes count:self.count];
}

- (id)mutableCopy
{
	return (id)[[NSMutableInlineData alloc] _initWithBytes:self.bytes count:self.count];
}

+ (instancetype)data
{
	return (id)[[NSMutableInlineData alloc] _initWithBytes:nullptr count:0];
}

+ (instancetype)dataWithCapacity:(NSUInteger)capacity
{
	return [[self alloc] initWithCapacity:capacity];
}

+ (instancetype)dataWithCount:(NSUInteger)count
{
	return [[self alloc] initWithCount:count];
}

- (instancetype)initWithData:(NSData *)data
{
	_NSMutableDataRejectReinitialization();
}

- (instancetype)initWithBytes:(void const *)bytes count:(NSUInteger)count
{
	_NSMutableDataRejectReinitialization();
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count
{
	_NSMutableDataRejectReinitialization();
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count freeWhenDone:(bool)freeBuffer
{
	_NSMutableDataRejectReinitialization();
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count
		deallocator:(nullable void (^)(void *, NSUInteger))deallocator
{
	_NSMutableDataRejectReinitialization();
}

- (instancetype)initWithCapacity:(NSUInteger)capacity
{
	_NSMutableDataRejectReinitialization();
}

- (instancetype)initWithCount:(NSUInteger)count
{
	_NSMutableDataRejectReinitialization();
}

- (void const *)bytes
{
	_NSMutableDataRejectInvocation();
}

- (NSUInteger)count
{
	_NSMutableDataRejectInvocation();
}

- (void)setCount:(NSUInteger)newCount NS_NORETURN
{
	_NSMutableDataRejectInvocation();
}

- (void *)mutableBytes
{
	_NSMutableDataRejectInvocation();
}

- (NSData *)subdataWithRange:(NSRange)range
{
	NSUInteger count = self.count;

	/* A range covering all bytes must still be handed back as an immutable snapshot, not this mutable object. */
	if (range.location == 0 && range.length == count)
		return [self copy];

	_NSRangeWithinUpperBound(range, count);

	if (range.length == 0)
		return (id)_NSZeroDataInstance;

	return [[NSInlineData alloc] _initWithBytes:(char const *)self.bytes + range.location count:range.length];
}

- (void)increaseCountBy:(NSUInteger)extraCount
{
	NSUInteger newCount;

	if (__builtin_add_overflow(self.count, extraCount, &newCount))
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"data overflow.");

	self.count = newCount;
}

- (void)appendBytes:(void const *)bytes count:(NSUInteger)count
{
	NSUInteger newCount;

	_NSRequireNonnullptr(bytes);

	if (count == 0)
		return;

	NSUInteger const oldCount = self.count;

	if (__builtin_add_overflow(oldCount, count, &newCount))
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"data overflow.");

	self.count = newCount;
	memcpy((char *)self.mutableBytes + oldCount, bytes, count);
}

- (void)appendData:(NSData *)other
{
	NSUInteger newCount;

	_NSRequireNonnil(other);

	NSDataRepresentation const rep = _NSDataGetRepresentation(other);
	NSUInteger const otherCount = rep.count;

	if (otherCount == 0)
		return;

	NSUInteger const oldCount = self.count;

	/* Find out how big we'll have to be. */
	if (__builtin_add_overflow(oldCount, otherCount, &newCount))
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"data overflow.");

	/* Appending our own bytes is a special case; make a copy so we don't read through a stale pointer. */
	if ((uintptr_t)other == (uintptr_t)self) {
		void *snapshot = _NSMalloc(oldCount);
		memcpy(snapshot, self.bytes, oldCount);

		self.count = newCount;
		memcpy((char *)self.mutableBytes + oldCount, snapshot, otherCount);
		free(snapshot);

		return;
	}

	self.count = newCount;
	memcpy((char *)self.mutableBytes + oldCount, rep.bytes, otherCount);
}

- (void)replaceBytesInRange:(NSRange)range withBytes:(void const *)bytes
{
	_NSRequireNonnullptr(bytes);

	[self replaceBytesInRange:range withBytes:bytes count:range.length];
}

- (void)replaceBytesInRange:(NSRange)range withBytes:(void const *)bytes count:(NSUInteger)count
{
	_NSRequireNonnullptr(bytes);

	NSUInteger const oldCount = self.count;

	_NSRangeWithinUpperBound(range, oldCount);

	/* newCount == (oldCount - range.length) + count; the left term cannot underflow given the checks. */
	NSUInteger newCount;
	if (__builtin_add_overflow(oldCount - range.length, count, &newCount))
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"data overflow.");

	NSUInteger const tailCount = oldCount - NSRangeMax(range);

	char *base;
	if (count > range.length) {
		/* Grow, then shift the tail rightwards into the freshly made room. */
		self.count = newCount;
		base = (char *)self.mutableBytes;
		memmove(base + range.location + count, base + NSRangeMax(range), tailCount);
	} else if (count < range.length) {
		/* Shift the tail leftwards first, then shrink to drop the slack. */
		base = (char *)self.mutableBytes;
		memmove(base + range.location + count, base + NSRangeMax(range), tailCount);
		self.count = newCount;
	} else
		base = (char *)self.mutableBytes;

	/* If none of the above cases were hit, we keep the same length. */

	if (count > 0)
		memcpy(base + range.location, bytes, count);
}

- (void)resetBytesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, self.count);

	if (range.length == 0)
		return;

	memset((char *)self.mutableBytes + range.location, 0, range.length);
}

- (void)setData:(NSData *)data
{
	_NSRequireNonnil(data);

	if ((uintptr_t)data == (uintptr_t)self)
		return;

	NSUInteger const count = data.count;
	self.count = count;

	if (count > 0)
		memcpy(self.mutableBytes, data.bytes, count);
}

@end

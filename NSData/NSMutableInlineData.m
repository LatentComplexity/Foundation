
#import <FoundationPrivate/NSData/NSData.h>

@interface NSMutableInlineData ()

- (void)_detachEnsuringCapacity:(NSUInteger)minCapacity OBJC_DIRECT;
- (void)_detachOpeningGapAtLocation:(NSUInteger)location removing:(NSUInteger)removeLength
	inserting:(NSUInteger)insertLength OBJC_DIRECT;
- (void)_detachDiscardingContentsEnsuringCapacity:(NSUInteger)minCapacity OBJC_DIRECT;

@end

@implementation NSMutableInlineData {
	NSDataBuffer *_buffer;
}

- (id)copy
{
	if (_buffer->count == 0)
		return (id)_NSZeroDataInstance;

	return [[NSInlineData alloc] _initWithBuffer:_buffer];
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

- (instancetype)_initWithBytes:(nullable void const *)bytes count:(NSUInteger)count OBJC_DIRECT
{
	_buffer = NSDataBufferCreateWithBytes(bytes, count);

	return self;
}

- (instancetype)_initWithBuffer:(NSDataBuffer *)buffer OBJC_DIRECT
{
	_buffer = NSDataBufferRetain(buffer);

	return self;
}

- (instancetype)_initWithCapacity:(NSUInteger)capacity OBJC_DIRECT
{
	_buffer = NSDataBufferCreate(capacity);

	return self;
}

- (instancetype)_initWithCount:(NSUInteger)count OBJC_DIRECT
{
	NSDataBuffer *buffer = NSDataBufferCreate(count);
	buffer->count = count;

	if (count > 0)
		memset(buffer->bytes, 0, count);

	_buffer = buffer;

	return self;
}

/* Preserves buffer->count. */
- (void)_detachEnsuringCapacity:(NSUInteger)minCapacity OBJC_DIRECT
{
	/* If we're sharing the buffer, fork; otherwise we own it uniquely and can grow it in place. */
	if (NSDataBufferIsUniquelyReferenced(_buffer) == false) {
		NSDataBuffer *fresh;

		fresh = NSDataBufferCreate(MAX(minCapacity, _buffer->count));

		if (_buffer->count > 0)
			memcpy(fresh->bytes, _buffer->bytes, _buffer->count);

		fresh->count = _buffer->count;

		NSDataBufferRelease(_buffer);
		_buffer = fresh;
	} else {
		/* A no-copy buffer can't be reallocated; hot-swap it to owned storage first. hash is cleared. */
		if (NSDataBufferIsReallocSafe(_buffer) == false)
			NSDataBufferMakeOwnedInPlace(_buffer, minCapacity);
		else
			NSDataBufferReserve(_buffer, minCapacity);

		/* About to mutate in place: the cached whole-buffer hash is now stale. */
		OSAtomicStore(&_buffer->hash, (NSUInteger)0, OSAtomicMemoryOrderRelaxed);
	}
}

/*
 * Detach (if shared) while moving surrounding bytes to their post-replacement layout: the removeLength bytes at
 * location become an uninitialized gap of insertLength bytes for the caller to fill. The surviving head and tail
 * land in their final positions, so each byte is written at most once. The caller must have already validated the
 * range and checked the resulting count for overflow.
 *
 * Modifies buffer->count directly.
 */
- (void)_detachOpeningGapAtLocation:(NSUInteger)location removing:(NSUInteger)removeLength
	inserting:(NSUInteger)insertLength OBJC_DIRECT
{
	NSUInteger const oldCount = _buffer->count;
	NSUInteger const newCount = oldCount - removeLength + insertLength;
	NSUInteger const tailLocation = location + removeLength;
	NSUInteger const tailCount = oldCount - tailLocation;

	/* If sharing the buffer, copy surviving bytes straight to their final slots. Otherwise, shift in place. */
	if (NSDataBufferIsUniquelyReferenced(_buffer) == false) {
		NSDataBuffer *const fresh = NSDataBufferCreate(newCount);
		char *const dst = fresh->bytes;
		char const *const src = (char const *)_buffer->bytes;

		if (location > 0)
			memcpy(dst, src, location);

		if (tailCount > 0)
			memcpy(dst + location + insertLength, src + tailLocation, tailCount);

		fresh->count = newCount;

		NSDataBufferRelease(_buffer);
		_buffer = fresh;
	} else {
		if (NSDataBufferIsReallocSafe(_buffer) == false)
			NSDataBufferMakeOwnedInPlace(_buffer, newCount);
		else
			NSDataBufferReserve(_buffer, newCount);

		char *const base = _buffer->bytes;

		/* Slide the tail to its final place; a same-length splice leaves it where it already is. */
		if (tailCount > 0 && insertLength != removeLength)
			memmove(base + location + insertLength, base + tailLocation, tailCount);

		_buffer->count = newCount;
		OSAtomicStore(&_buffer->hash, (NSUInteger)0, OSAtomicMemoryOrderRelaxed);
	}
}

/*
 * Like -_detachEnsuringCapacity:, but for callers that overwrite the entire contents: nothing is preserved, so a
 * shared or foreign buffer is dropped for a fresh owned allocation rather than copied.
 *
 * Does not modify buffer->count.
 */
- (void)_detachDiscardingContentsEnsuringCapacity:(NSUInteger)minCapacity OBJC_DIRECT
{
	if (NSDataBufferIsUniquelyReferenced(_buffer) && NSDataBufferIsReallocSafe(_buffer)) {
		NSDataBufferReserve(_buffer, minCapacity);
		OSAtomicStore(&_buffer->hash, (NSUInteger)0, OSAtomicMemoryOrderRelaxed);
	} else {
		/* Shared, or foreign storage we can't reuse: drop our reference and start fresh. */
		NSDataBufferRelease(_buffer);
		_buffer = NSDataBufferCreate(minCapacity);
	}
}

- (void const *)bytes
{
	return _buffer->bytes;
}

- (NSUInteger)count
{
	return _buffer->count;
}

- (void)setCount:(NSUInteger)newCount
{
	NSUInteger oldCount;

	oldCount = _buffer->count;

	if (newCount == oldCount)
		return;

	[self _detachEnsuringCapacity:newCount];

	/* Growth is zero-filled. */
	if (newCount > oldCount)
		memset(_buffer->bytes + oldCount, 0, newCount - oldCount);

	_buffer->count = newCount;
}

- (void *)mutableBytes
{
	/* Vending a writable pointer is a mutation. */
	[self _detachEnsuringCapacity:_buffer->count];

	return _buffer->bytes;
}

- (NSData *)subdataWithRange:(NSRange)range
{
	if (range.location == 0 && range.length == _buffer->count)
		return [self copy];

	_NSRangeWithinUpperBound(range, _buffer->count);

	if (range.length == 0)
		return (id)_NSZeroDataInstance;

	/* Share the buffer with an immutable window; the window holds a ref, so our next mutation forks. */
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

/*
 * Relational comparison or subtraction of unrelated pointers is undefined in C. Since basically every modern machine
 * has a flat address space, compare the integer representations of their pointers.
 */
[[clang::always_inline]]
static inline bool
NSDataByteRangesOverlap(void const *const firstBytes, NSUInteger const firstCount,
			void const *const secondBytes, NSUInteger const secondCount)
{
	uintptr_t const first = (uintptr_t)firstBytes;
	uintptr_t const second = (uintptr_t)secondBytes;

	if (first <= second)
		return second - first < firstCount;

	return first - second < secondCount;
}

- (void)appendBytes:(void const *)bytes count:(NSUInteger)count
{
	_NSRequireNonnullptr(bytes);

	if (count == 0)
		return;

	NSUInteger const oldCount = _buffer->count;

	NSUInteger newCount;
	if (__builtin_add_overflow(oldCount, count, &newCount))
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"data overflow.");

	NSDataBuffer *const oldBuffer = _buffer;
	bool const isUnique = NSDataBufferIsUniquelyReferenced(oldBuffer);
	bool const isReallocSafe = NSDataBufferIsReallocSafe(oldBuffer);

	/* No storage can move. memmove supports every overlap between the input and the appended tail. */
	if (isUnique && isReallocSafe && newCount <= oldBuffer->capacity) {
		memmove(oldBuffer->bytes + oldCount, bytes, count);
		oldBuffer->count = newCount;
		OSAtomicStore(&oldBuffer->hash, (NSUInteger)0, OSAtomicMemoryOrderRelaxed);
		return;
	}

	/*
	 * Preserve the realloc fast path only when the source is disjoint from the whole allocation, including
	 * unused capacity. realloc() cannot then invalidate it, and the grown allocation cannot overlap a distinct
	 * live object.
	 */
	if (isUnique && isReallocSafe &&
	    NSDataByteRangesOverlap(bytes, count, oldBuffer->bytes, oldBuffer->capacity) == false) {
		NSDataBufferReserve(oldBuffer, newCount);
		memcpy(oldBuffer->bytes + oldCount, bytes, count);
		oldBuffer->count = newCount;
		OSAtomicStore(&oldBuffer->hash, (NSUInteger)0, OSAtomicMemoryOrderRelaxed);
		return;
	}

	/*
	 * Shared, foreign, or realloc-aliasing storage must remain alive until both source ranges have been copied.
	 * In particular, a foreign deallocator may invalidate bytes elsewhere in the same enclosing allocation.
	 * A shared fork retains the existing exact-fit behaviour; unique storage keeps geometric growth.
	 */
	NSUInteger const freshCapacity = isUnique ?
		NSDataBufferCapacityForGrowth(oldBuffer->capacity, newCount) : newCount;
	NSDataBuffer *const fresh = NSDataBufferCreate(freshCapacity);

	if (oldCount > 0)
		memcpy(fresh->bytes, oldBuffer->bytes, oldCount);
	memcpy(fresh->bytes + oldCount, bytes, count);
	fresh->count = newCount;

	NSDataBufferRelease(oldBuffer);
	_buffer = fresh;
}

- (void)appendData:(NSData *)other
{
	_NSRequireNonnil(other);

	NSUInteger const otherCount = other.count;
	if (otherCount == 0)
		return;

	NSDataRepresentation const rep = _NSDataGetRepresentation(other);

	[self appendBytes:rep.bytes count:rep.count];
}

- (void)replaceBytesInRange:(NSRange)range withBytes:(void const *)bytes count:(NSUInteger)count
{
	_NSRequireNonnullptr(bytes);

	NSUInteger const oldCount = _buffer->count;
	_NSRangeWithinUpperBound(range, oldCount);

	NSUInteger newCount;
	if (__builtin_add_overflow(oldCount - range.length, count, &newCount))
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"data overflow.");

	NSDataBuffer *const oldBuffer = _buffer;
	bool const isUnique = NSDataBufferIsUniquelyReferenced(oldBuffer);
	bool const isReallocSafe = NSDataBufferIsReallocSafe(oldBuffer);
	NSUInteger const tailLocation = range.location + range.length;
	NSUInteger const tailCount = oldCount - tailLocation;

	/*
	 * When replacement does not grow unique owned storage, copy the input before shifting the tail. The
	 * replacement destination ends no later than the old tail begins, so it cannot destroy bytes needed by the
	 * subsequent shift; memmove makes the input copy safe for every internal overlap.
	 */
	if (isUnique && isReallocSafe && count <= range.length) {
		char *const oldBytes = oldBuffer->bytes;

		/* Move in our given bytes. If we have a tail, or the replacement created a gap, move the bytes. */
		if (count > 0)
			memmove(oldBytes + range.location, bytes, count);
		if (tailCount > 0 && count != range.length)
			memmove(oldBytes + range.location + count, oldBytes + tailLocation, tailCount);

		oldBuffer->count = newCount;
		OSAtomicStore(&oldBuffer->hash, (NSUInteger)0, OSAtomicMemoryOrderRelaxed);
		return;
	}

	/*
	 * A unique foreign buffer must survive until the input is copied because its deallocator may invalidate
	 * memory outside the represented range. Growing owned storage also needs a fresh buffer when the input
	 * touches any part of its allocation: realloc or the tail shift could otherwise invalidate or overwrite
	 * the input first.
	 */
	if (isUnique && (isReallocSafe == false ||
	    NSDataByteRangesOverlap(bytes, count, oldBuffer->bytes, oldBuffer->capacity))) {
		NSUInteger freshCapacity = oldBuffer->capacity;

		if (newCount > freshCapacity)
			freshCapacity = NSDataBufferCapacityForGrowth(freshCapacity, newCount);

		NSDataBuffer *const fresh = NSDataBufferCreate(freshCapacity);
		char *const dst = fresh->bytes;
		char const *const src = oldBuffer->bytes;

		/* If applicable, copy in pre-range bytes, range bytes, then tail bytes. */
		if (range.location > 0)
			memcpy(dst, src, range.location);
		if (count > 0)
			memcpy(dst + range.location, bytes, count);
		if (tailCount > 0)
			memcpy(dst + range.location + count, src + tailLocation, tailCount);

		fresh->count = newCount;
		NSDataBufferRelease(oldBuffer);
		_buffer = fresh;
		return;
	}

	/* Shared storage forks, while disjoint growing input may retain the realloc-and-shift fast path. */
	[self _detachOpeningGapAtLocation:range.location removing:range.length inserting:count];

	if (count > 0)
		memcpy(_buffer->bytes + range.location, bytes, count);
}

/* TODO: if location == 0 && length == _buffer->count, release the old and calloc() a new buffer by hand. */
- (void)resetBytesInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, _buffer->count);

	if (range.length == 0)
		return;

	[self _detachEnsuringCapacity:_buffer->count];
	memset(_buffer->bytes + range.location, 0, range.length);
}

- (void)setData:(NSData *)data
{
	_NSRequireNonnil(data);

	if ((uintptr_t)data == (uintptr_t)self)
		return;

	NSUInteger const newCount = data.count;

	/* None of the old bytes survive, so fork without copying them and then overwrite outright. */
	[self _detachDiscardingContentsEnsuringCapacity:newCount];

	if (newCount > 0)
		memcpy(_buffer->bytes, data.bytes, newCount);

	_buffer->count = newCount;
}

- (void)dealloc
{
	NSDataBufferRelease(_buffer);
}

@end

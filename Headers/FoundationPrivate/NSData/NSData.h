
#import <Foundation/NSData.h>
#import <FoundationPrivate/NSObject/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Buffer

/*
 * Reference-counted resizable byte buffer shared between NSData objects for implementing CoW. The refcount is >= 1
 * for as long as the buffer is alive. bytes is never null; -mutableBytes can hand out a "usable" pointer even for
 * empty data.
 *
 * count is the logical length of the whole data the buffer holds; capacity >= count is how much storage is actually
 * allocated. For a "whole" object (NSInlineData / NSMutableInlineData) the count and the cached hash live here so that
 * all objects sharing the buffer agree on them and only compute the hash once. This is sound for as long as a buffer
 * is mutated in place only while uniquely referenced; any mutation of a shared buffer forks first. count and bytes
 * are therefore deliberately non-atomic (no sharer ever observes them mid-mutation); hash is atomic only for the
 * benign lazy-compute race. Do not make count or bytes atomic or read them off a shared, mutating buffer.
 *
 * deallocator is a Block in every case (free or otherwise): the bytes are released by invoking it with (bytes, count).
 * Owned/malloc storage uses the shared free block and is realloc-safe; externally-owned (freeWhenDone:false) storage
 * uses the shared no-op block; a no-copy initializer's custom block is stored directly. The field is explicitly
 * strong because paranoia. Every buffer is calloc'ed to appease ARC.
 */

[[gnu::visibility("hidden")]]
extern void
(^const NSDataBufferFreeBlock)(void *, NSUInteger);

[[gnu::visibility("hidden")]]
extern void
(^const NSDataBufferNoFreeBlock)(void *, NSUInteger);

typedef void (^NSDataDeallocator)(void *bytes, NSUInteger count);

typedef struct NSDataBuffer {
	NSUInteger _Atomic refcount;
	char *bytes;
	NSUInteger count;
	NSUInteger capacity;
	NSUInteger _Atomic hash;
	NSDataDeallocator __strong deallocator;
} NSDataBuffer;

/*
 * TODO: all of these routines should be prefixed with an underscore, and they should take a method context.
 * TODO: There is one method that reallocates, and so thusly needs it. Everyone else can just [[maybe_unused]].
 */

[[clang::always_inline]]
static inline NSDataBuffer *
NSDataBufferRetain(NSDataBuffer *const buffer)
{
	OSAtomicAdd(&buffer->refcount, 1);
	return buffer;
}

[[clang::always_inline]]
static inline void
NSDataBufferRelease(NSDataBuffer *const buffer)
{
	/* Do not weaken this to relaxed. */
	if (OSAtomicSubtract(&buffer->refcount, 1) == 1) {
		buffer->deallocator(buffer->bytes, buffer->count);
		buffer->deallocator = nil;
		free(buffer);
	}
}

[[clang::always_inline]]
static inline bool
NSDataBufferIsUniquelyReferenced(NSDataBuffer const *const buffer)
{
	return OSAtomicLoad(&buffer->refcount) == 1;
}

/* True if the bytes are owned by us through malloc() and may be grown in place. */
[[clang::always_inline]]
static inline bool
NSDataBufferIsReallocSafe(NSDataBuffer *const buffer)
{
	return buffer->deallocator == NSDataBufferFreeBlock;
}

/* Apply the buffer's geometric growth policy without allocating or modifying the buffer. */
[[clang::always_inline]]
static inline NSUInteger
NSDataBufferCapacityForGrowth(NSUInteger const capacity, NSUInteger const minCapacity)
{
	NSUInteger grownCapacity;

	if (__builtin_mul_overflow(capacity, 2, &grownCapacity))
		return minCapacity;

	return MAX(grownCapacity, minCapacity);
}

/* Allocate an owned buffer with a given capacity, count 0, and a refcount of 1. */
[[clang::always_inline]]
static inline NSDataBuffer *
NSDataBufferCreate(NSUInteger const capacity)
{
	NSDataBuffer *const buffer = (void *_Nonnull)calloc(1, sizeof(*buffer));

	/* Always keep at least one byte so that bytes is never null, even for empty data. */
	buffer->capacity = MAX(capacity, (NSUInteger)1);
	buffer->bytes = (void *_Nonnull)malloc(buffer->capacity);
	buffer->count = 0;
	buffer->deallocator = NSDataBufferFreeBlock;
	OSAtomicInit(&buffer->refcount, 1);
	OSAtomicInit(&buffer->hash, 0);

	return buffer;
}

/* Allocate an owned buffer holding a copy of some count of bytes. bytes == null iff the count is zero. */
[[clang::always_inline]]
static inline NSDataBuffer *
NSDataBufferCreateWithBytes(void const *const bytes, NSUInteger const count)
{
	NSDataBuffer *const buffer = NSDataBufferCreate(count);

	if (count > 0)
		memcpy(buffer->bytes, bytes, count);

	buffer->count = count;

	return buffer;
}

/* Wrap caller-owned bytes without copying. freeWhenDone selects the free block (realloc-safe) or the no-op block. */
[[clang::always_inline]]
static inline NSDataBuffer *
NSDataBufferAdopt(void *const bytes, NSUInteger const count, bool const freeWhenDone)
{
	NSDataBuffer *const buffer = (void *_Nonnull)calloc(1, sizeof(*buffer));

	buffer->bytes = bytes;
	buffer->count = count;
	buffer->capacity = count;
	buffer->deallocator = freeWhenDone ? NSDataBufferFreeBlock : NSDataBufferNoFreeBlock;
	OSAtomicInit(&buffer->refcount, 1);
	OSAtomicInit(&buffer->hash, 0);

	return buffer;
}

/*
 * Wrap caller-owned bytes without copying, releasing them later through a custom Block. If the Block is nonnull, it
 * is copied by assignment to the buffer's strong field. A nil Block == no-op.
 */
[[clang::always_inline]]
static inline NSDataBuffer *
NSDataBufferAdoptWithBlock(void *const bytes, NSUInteger const count, NSDataDeallocator deallocator)
{
	NSDataBuffer *const buffer = (void *_Nonnull)calloc(1, sizeof(*buffer));

	buffer->bytes = bytes;
	buffer->count = count;
	buffer->capacity = count;
	/* Strong assignment copies a stack block; a nil block means "leave the bytes alone". */
	buffer->deallocator = deallocator != nil ? deallocator : NSDataBufferNoFreeBlock;
	OSAtomicInit(&buffer->refcount, 1);
	OSAtomicInit(&buffer->hash, 0);

	return buffer;
}

/*
 * Ensure the buffer's capacity is at least the given capacity. Caller must have already forked if buffer was shared.
 */
[[clang::always_inline]]
static inline void
NSDataBufferReserve(NSDataBuffer *const buffer, NSUInteger const minCapacity)
{
	/* Precondition: the buffer is realloc-safe (owns its bytes via malloc); the detach helpers guarantee this. */
	if (minCapacity <= buffer->capacity)
		return;

	/* Grow geometrically so that a run of appends amortizes to O(1) per byte. */
	NSUInteger const newCapacity = NSDataBufferCapacityForGrowth(buffer->capacity, minCapacity);

	void *const grown = realloc(buffer->bytes, newCapacity);
	if (grown == nullptr)
		[NSException raise:NSMallocException format:@"%s: failed to grow data buffer.", __PRETTY_FUNCTION__];

	buffer->bytes = grown;
	buffer->capacity = newCapacity;
}

/*
 * Convert a uniquely-referenced, non-realloc-safe (no-copy) buffer into owned storage of at least minCapacity,
 * copying its count bytes across and running the old deallocator exactly once. Afterwards the buffer is realloc-safe.
 * The precondition is NSDataBufferIsUniquelyReferenced(buffer) && NSDataBufferIsReallocSafe(buffer) == false; never
 * call it shared.
 */
[[clang::always_inline]]
static inline void
NSDataBufferMakeOwnedInPlace(NSDataBuffer *const buffer, NSUInteger const minCapacity)
{
	/* We can't realloc a foreign pointer, so move to owned. */
	NSUInteger const newCapacity = MAX(MAX(buffer->count, minCapacity), (NSUInteger)1);
	void *const fresh = (void *_Nonnull)malloc(newCapacity);

	if (buffer->count > 0)
		memcpy(fresh, buffer->bytes, buffer->count);

	/* Run the foreign cleanup on the old bytes exactly once, then become an owned, realloc-safe buffer. */
	buffer->deallocator(buffer->bytes, buffer->count);

	buffer->bytes = fresh;
	buffer->capacity = newCapacity;
	buffer->deallocator = NSDataBufferFreeBlock;
}

#pragma mark - Classes

@interface NSDataTemplate : NSData
@end

@interface NSZeroData : NSData
@end

@interface NSInlineData : NSData

- (instancetype)_initWithBytes:(void const *)bytes count:(NSUInteger)count OBJC_DIRECT;
- (instancetype)_initAdoptingBuffer:(NSDataBuffer *)buffer OBJC_DIRECT;
- (instancetype)_initWithBuffer:(NSDataBuffer *)buffer OBJC_DIRECT;

@end

@interface NSSubrangeData : NSData

- (instancetype)_initWithBuffer:(NSDataBuffer *)buffer base:(NSUInteger)base count:(NSUInteger)count OBJC_DIRECT;

@end

@interface NSMutableDataTemplate : NSMutableData
@end

@interface NSMutableInlineData : NSMutableData

- (instancetype)_initWithCapacity:(NSUInteger)capacity OBJC_DIRECT;
- (instancetype)_initWithCount:(NSUInteger)count OBJC_DIRECT;
- (instancetype)_initWithBytes:(nullable void const *)bytes count:(NSUInteger)count OBJC_DIRECT;
- (instancetype)_initAdoptingBuffer:(NSDataBuffer *)buffer OBJC_DIRECT;
- (instancetype)_initWithBuffer:(NSDataBuffer *)buffer OBJC_DIRECT;

@end

typedef struct [[gnu::may_alias]] NSInlineDataLayout {
	void const *const isa;
	NSDataBuffer const *const buffer;
} NSInlineDataLayout;

typedef struct [[gnu::may_alias]] NSSubrangeDataLayout {
	void const *const isa;
	NSDataBuffer const *const buffer;
	NSUInteger const base;
	NSUInteger const count;
	NSUInteger const _Atomic hash;
} NSSubrangeDataLayout;

typedef struct [[gnu::may_alias]] NSMutableInlineDataLayout {
	void const *const isa;
	NSDataBuffer const *const buffer;
} NSMutableInlineDataLayout;

#pragma mark - Constants

[[gnu::visibility("hidden")]]
extern unsigned __int128 _NSDataHashKey;

[[gnu::visibility("hidden")]]
extern NSUInteger _NSZeroDataHash;

[[gnu::visibility("hidden")]]
extern Class _NSDataClass;

[[gnu::visibility("hidden")]]
extern Class _NSDataTemplateClass;

[[gnu::visibility("hidden")]]
extern Class _NSZeroDataClass;

[[gnu::visibility("hidden")]]
extern Class _NSInlineDataClass;

[[gnu::visibility("hidden")]]
extern Class _NSSubrangeDataClass;

[[gnu::visibility("hidden")]]
extern Class _NSMutableDataClass;

[[gnu::visibility("hidden")]]
extern Class _NSMutableDataTemplateClass;

[[gnu::visibility("hidden")]]
extern Class _NSMutableInlineDataClass;

[[gnu::visibility("hidden")]]
extern NSZeroData *_NSZeroDataInstance;

#pragma mark - Validation

[[clang::always_inline]]
static inline void
_NSCDataSearchOptionsCheck(NSMethodContext const context, NSDataSearchOptions options, char const *const optName)
{
	if (((NSUInteger)options & ~((NSUInteger)NSDataSearchBackwards | (NSUInteger)NSDataSearchAnchored)) != 0) \
		_NSRaiseInvalidOption(context, optName);
}

#define _NSDataSearchOptionsCheck(options) \
	_NSCDataSearchOptionsCheck(MethodContext, options, #options)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCDataRejectReinitialization(NSMethodContext const ctx)
{
	_NSClusterRejectReinitialization(ctx, _NSDataClass,
		(NSClassSpan) {
			.classes = (Class[]){ _NSZeroDataClass, _NSInlineDataClass, _NSSubrangeDataClass },
			.count = 3
		}, _NSSubclassingPermitted);
}
#define _NSDataRejectReinitialization() \
	_NSCDataRejectReinitialization(MethodContext)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCMutableDataRejectReinitialization(NSMethodContext const ctx)
{
	_NSClusterRejectReinitialization(ctx, _NSDataClass,
		(NSClassSpan) {
			.classes = (Class[]){ _NSMutableInlineDataClass },
			.count = 1
		}, _NSSubclassingPermitted);
}

#define _NSMutableDataRejectReinitialization() \
	_NSCMutableDataRejectReinitialization(MethodContext)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCDataRejectInvocation(NSMethodContext const ctx)
{
	_NSClusterRejectInvocation(ctx, _NSDataClass, _NSDataTemplateClass, _NSSubclassingPermitted);
}

#define _NSDataRejectInvocation() \
	_NSCDataRejectInvocation(MethodContext)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCMutableDataRejectInvocation(NSMethodContext const ctx)
{
	_NSClusterRejectInvocation(ctx, _NSMutableDataClass, _NSMutableDataTemplateClass, _NSSubclassingPermitted);
}

#define _NSMutableDataRejectInvocation() \
	_NSCMutableDataRejectInvocation(MethodContext)

#pragma mark - Generics

typedef struct NSDataRepresentation {
	void const *bytes;
	NSUInteger count;
} NSDataRepresentation;

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline NSDataRepresentation
_NSDataGetRepresentation(NSData *__unsafe_unretained otherData)
{
	Class const c = object_getClass(otherData);

	if (c == _NSZeroDataClass)
		return (NSDataRepresentation) {
			.bytes = nullptr,
			.count = 0
		};
	else if (c == _NSInlineDataClass || c == _NSMutableInlineDataClass) {
		NSInlineDataLayout *layout = (__bridge NSInlineDataLayout *)otherData;
		return (NSDataRepresentation) {
			.bytes = layout->buffer->bytes,
			.count = layout->buffer->count
		};
	} else if (c == _NSSubrangeDataClass) {
		NSSubrangeDataLayout *layout = (__bridge NSSubrangeDataLayout *)otherData;
		return (NSDataRepresentation) {
			.bytes = layout->buffer->bytes + layout->base,
			.count = layout->count
		};
	} else
		return (NSDataRepresentation) {
			.bytes = otherData.bytes,
			.count = otherData.count
		};
}

NS_ASSUME_NONNULL_END

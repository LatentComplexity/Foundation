
#import <FoundationPrivate/NSObject/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
#import <FoundationPrivate/NSIndexSet/NSIndexSet.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Buffer

typedef struct NSArrayBuffer {
	NSUInteger _Atomic refcount;
	id<NSObject> __unsafe_unretained _Nonnull *_Nonnull objects;
	NSUInteger count;
	NSUInteger capacity;
	NSUInteger _Atomic hash;
} NSArrayBuffer;

enum : NSUInteger {
	NSArrayBufferMaximumCount = NSUIntegerMax / sizeof(id)
};

[[clang::always_inline]]
static inline NSArrayBuffer *
NSArrayBufferRetain(NSArrayBuffer *const buffer)
{
	OSAtomicAdd(&buffer->refcount, 1);
	return buffer;
}

[[clang::always_inline]]
static inline void
NSArrayBufferRelease(NSArrayBuffer *const buffer)
{
	/* Do not weaken this to relaxed. */
	if (OSAtomicSubtract(&buffer->refcount, 1) == 1) {
		for (NSUInteger i = 0; i < buffer->count; ++i)
			objc_release(buffer->objects[i]);

		free(buffer->objects);
		free(buffer);
	}
}

[[clang::always_inline]]
static inline bool
NSArrayBufferIsUniquelyReferenced(NSArrayBuffer const *const buffer)
{
	return OSAtomicLoad(&buffer->refcount) == 1;
}

[[clang::always_inline]]
static inline NSArrayBuffer *
NSArrayBufferCreate(NSUInteger const capacity)
{
	/* TODO: refactor to use _NSMalloc(). */
	void *_Nullable malloc(NSUInteger);

	NSUInteger const actualCapacity = MAX(capacity, (NSUInteger)1);

	if (actualCapacity > NSArrayBufferMaximumCount)
		[NSException raise:NSMallocException format:@"%s: failed to allocate array buffer.",
			__PRETTY_FUNCTION__];

	NSArrayBuffer *const buffer = (NSArrayBuffer *)malloc(sizeof(*buffer));
	if (buffer == nullptr)
		[NSException raise:NSMallocException format:@"%s: failed to allocate array buffer.",
			__PRETTY_FUNCTION__];

	buffer->objects = (id __unsafe_unretained *)(void *)malloc(actualCapacity * sizeof(id));
	if (buffer->objects == nullptr) {
		free(buffer);
		[NSException raise:NSMallocException format:@"%s: failed to allocate array storage.",
			__PRETTY_FUNCTION__];
	}

	buffer->capacity = actualCapacity;
	buffer->count = 0;
	OSAtomicInit(&buffer->hash, 0);
	OSAtomicInit(&buffer->refcount, 1);

	return buffer;
}

[[clang::always_inline]]
static inline void
NSArrayBufferReserve(NSArrayBuffer *const buffer, NSUInteger const minCapacity)
{
	if (minCapacity <= buffer->capacity)
		return;

	if (minCapacity > NSArrayBufferMaximumCount)
		[NSException raise:NSMallocException format:@"%s: failed to grow array buffer.",
			__PRETTY_FUNCTION__];

	NSUInteger newCapacity;
	if (__builtin_mul_overflow(buffer->capacity, (NSUInteger)2, &newCapacity) ||
	    newCapacity > NSArrayBufferMaximumCount)
		newCapacity = minCapacity;
	else
		newCapacity = MAX(newCapacity, minCapacity);

	/* TODO: I'm pretty sure this can't overflow given the check above? */
	NSUInteger byteCapacity;
	if (__builtin_mul_overflow(newCapacity, sizeof(id), &byteCapacity))
		[NSException raise:NSMallocException format:@"%s: failed to grow array buffer.",
			__PRETTY_FUNCTION__];

	void *const grown = realloc(buffer->objects, byteCapacity);
	if (grown == nullptr)
		[NSException raise:NSMallocException format:@"%s: failed to grow array buffer.",
			__PRETTY_FUNCTION__];

	buffer->objects = (id __unsafe_unretained *)(void *)grown;
	buffer->capacity = newCapacity;
}

#pragma mark - Classes

@interface NSArrayTemplate : NSArray
@end

@interface NSZeroArray : NSArray
@end

@interface NSSingleEntryArray : NSArray
- (instancetype)_initWithObject:(id)anObject OBJC_DIRECT;
@end

@interface NSInlineArray : NSArray

- (instancetype)_initWithBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT;
- (instancetype)_initAdoptingBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT;

@end

@interface NSSubrangeArray : NSArray
- (instancetype)_initWithBuffer:(NSArrayBuffer *)buffer base:(NSUInteger)base count:(NSUInteger)count OBJC_DIRECT;
@end

@interface NSMutableArrayTemplate : NSMutableArray
@end

@interface NSMutableInlineArray : NSMutableArray

- (instancetype)_initWithBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT;
- (instancetype)_initAdoptingBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT;

@end

typedef struct [[gnu::may_alias]] NSSingleEntryArrayLayout {
	void const *const isa;
	id __unsafe_unretained const anObject;
} NSSingleEntryArrayLayout;

typedef struct [[gnu::may_alias]] NSInlineArrayLayout {
	void const *const isa;
	NSArrayBuffer const *const buffer;
} NSInlineArrayLayout;

typedef struct [[gnu::may_alias]] NSSubrangeArrayLayout {
	void const *const isa;
	NSArrayBuffer const *const buffer;
	NSUInteger const base;
	NSUInteger const count;
	NSUInteger _Atomic const hash;
} NSSubrangeArrayLayout;

typedef struct [[gnu::may_alias]] NSMutableInlineArrayLayout {
	void const *const isa;
	NSArrayBuffer const *const buffer;
	NSUInteger mutations;
} NSMutableInlineArrayLayout;

#pragma mark - Enumerators

@interface NSArrayEnumerator : NSEnumerator
+ (instancetype)_enumeratorWithArray:(NSArray *)array OBJC_DIRECT;
@end

@interface NSArrayReverseEnumerator : NSEnumerator
+ (instancetype)_enumeratorWithArray:(NSArray *)array OBJC_DIRECT;
@end

@interface NSZeroArrayEnumerator : NSEnumerator
@end

@interface NSSingleEntryArrayEnumerator : NSEnumerator
+ (instancetype)_enumeratorWithObject:(id)anObject OBJC_DIRECT;
@end

@interface NSInlineArrayEnumerator : NSEnumerator
+ (instancetype)_enumeratorWithBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT;
@end

@interface NSInlineArrayReverseEnumerator : NSEnumerator
+ (instancetype)_enumeratorWithBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT;
@end

@interface NSSubrangeArrayEnumerator : NSEnumerator
+ (instancetype)_enumeratorWithBuffer:(NSArrayBuffer *)buffer base:(NSUInteger)base
		count:(NSUInteger)count OBJC_DIRECT;
@end

@interface NSSubrangeArrayReverseEnumerator : NSEnumerator
+ (instancetype)_enumeratorWithBuffer:(NSArrayBuffer *)buffer base:(NSUInteger)base
		count:(NSUInteger)count OBJC_DIRECT;
@end

@interface NSMutableInlineArrayEnumerator : NSEnumerator
+ (instancetype)_enumeratorWithArray:(NSMutableInlineArray *)array OBJC_DIRECT;
@end

@interface NSMutableInlineArrayReverseEnumerator : NSEnumerator
+ (instancetype)_enumeratorWithArray:(NSMutableInlineArray *)array OBJC_DIRECT;
@end

#pragma mark - Constants

[[gnu::visibility("hidden")]]
extern unsigned __int128 _NSArrayHashKey;

[[gnu::visibility("hidden")]]
extern NSUInteger _NSZeroArrayHash;

[[gnu::visibility("hidden")]]
extern Class _NSArrayClass;

[[gnu::visibility("hidden")]]
extern Class _NSArrayTemplateClass;

[[gnu::visibility("hidden")]]
extern Class _NSZeroArrayClass;

[[gnu::visibility("hidden")]]
extern Class _NSSingleEntryArrayClass;

[[gnu::visibility("hidden")]]
extern Class _NSInlineArrayClass;

[[gnu::visibility("hidden")]]
extern Class _NSSubrangeArrayClass;

[[gnu::visibility("hidden")]]
extern Class _NSMutableArrayClass;

[[gnu::visibility("hidden")]]
extern Class _NSMutableArrayTemplateClass;

[[gnu::visibility("hidden")]]
extern Class _NSMutableInlineArrayClass;

[[gnu::visibility("hidden")]]
extern NSZeroArray *_NSZeroArrayInstance;

[[gnu::visibility("hidden")]]
extern NSZeroArrayEnumerator *_NSZeroArrayEnumeratorInstance;

#pragma mark - Validation

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline void
_NSCForeignArrayRequireNonnilObjectAtIndex(NSMethodContext const ctx, char const *const arrayName,
					id __unsafe_unretained obj, NSUInteger const index)
{
	if (obj == nil)
		_NSRaiseException(ctx, NSInvalidArgumentException, @"'%s' returned nil at index %lu.", arrayName,
					index);
}

#define _NSForeignReceiverArrayRequireNonnilObjectAtIndex(obj, index) \
	_NSCForeignArrayRequireNonnilObjectAtIndex(MethodContext, "self", obj, index)

#define _NSForeignArrayRequireNonnilObjectAtIndex(arrayName, obj, index) \
	_NSCForeignArrayRequireNonnilObjectAtIndex(MethodContext, #arrayName, obj, index)

[[clang::always_inline]]
static inline void
_NSCForeignArrayRequireCountWithinBounds(NSMethodContext const ctx, char const *const arrayName,
					NSUInteger const count)
{
	if (count > NSArrayBufferMaximumCount)
		_NSRaiseException(ctx, NSInvalidArgumentException, @"'%s' overflow.", arrayName);
}

#define _NSForeignArrayRequireCountWithinBounds(arrayName, count) \
	_NSCForeignArrayRequireCountWithinBounds(MethodContext, #arrayName, count)

[[clang::always_inline]]
static inline void
_NSCArrayRequireIndexWithinBounds(NSMethodContext const ctx, NSUInteger const index, NSUInteger const count,
					char const *const indexName)
{
	if (index >= count)
		_NSRaiseException(ctx, NSRangeException,
			@"'%s' with value %lu extends beyond array count of %lu.", indexName, index, count);
}

#define _NSArrayRequireIndexWithinBounds(index, count) \
	_NSCArrayRequireIndexWithinBounds(MethodContext, index, count, #index)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCArrayRejectReinitialization(NSMethodContext const ctx)
{
	_NSClusterRejectReinitialization(ctx, _NSArrayClass,
		(NSClassSpan) {
			.classes = (Class[]){ _NSZeroArrayClass, _NSSingleEntryArrayClass,
						_NSInlineArrayClass, _NSSubrangeArrayClass,
						_NSMutableInlineArrayClass },
			.count = 5
		}, _NSSubclassingPermitted);
}

#define _NSArrayRejectReinitialization() \
	_NSCArrayRejectReinitialization(MethodContext)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCArrayRejectInvocation(NSMethodContext const ctx)
{
	_NSClusterRejectInvocation(ctx, _NSArrayClass, _NSArrayTemplateClass, _NSSubclassingPermitted);
}

#define _NSArrayRejectInvocation() \
	_NSCArrayRejectInvocation(MethodContext)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCMutableArrayRejectReinitialization(NSMethodContext const ctx)
{
	_NSClusterRejectReinitialization(ctx, _NSMutableArrayClass,
		(NSClassSpan) {
			.classes = (Class[]){ _NSMutableInlineArrayClass },
			.count = 1
		}, _NSSubclassingPermitted);
}

#define _NSMutableArrayRejectReinitialization() \
	_NSCMutableArrayRejectReinitialization(MethodContext)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCMutableArrayRejectInvocation(NSMethodContext const ctx)
{
	_NSClusterRejectInvocation(ctx, _NSMutableArrayClass, _NSMutableArrayTemplateClass, _NSSubclassingPermitted);
}

#define _NSMutableArrayRejectInvocation() \
	_NSCMutableArrayRejectInvocation(MethodContext)

#pragma mark - Generics

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpadded"

typedef struct NSArrayRepresentation {
	NSArray *__unsafe_unretained array;
	Class _Nullable arrayCls;
	id __unsafe_unretained const _Nonnull *_Nullable objects;
	NSUInteger count;
	bool isPrivate;
} NSArrayRepresentation;

#pragma clang diagnostic pop

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline NSArrayRepresentation
_NSArrayGetRepresentation(NSArray *__unsafe_unretained array)
{
	NSArrayRepresentation rep = {};
	rep.array = array;
	Class const c = object_getClass(array);
	rep.arrayCls = c;
	rep.isPrivate = true;

	if (c == _NSZeroArrayClass)
		return rep;
	else if (c == _NSSingleEntryArrayClass) {
		rep.objects = &((__bridge NSSingleEntryArrayLayout *)array)->anObject;
		rep.count = 1;
	} else if (c == _NSInlineArrayClass || c == _NSMutableInlineArrayClass) {
		NSInlineArrayLayout *layout = (__bridge NSInlineArrayLayout *)array;
		rep.objects = layout->buffer->objects;
		rep.count = layout->buffer->count;
	} else if (c == _NSSubrangeArrayClass) {
		NSSubrangeArrayLayout *layout = (__bridge NSSubrangeArrayLayout *)array;
		rep.objects = layout->buffer->objects + layout->base;
		rep.count = layout->count;
	} else {
		rep.objects = nullptr;
		rep.count = array.count;
		rep.isPrivate = false;
	}

	return rep;
}

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline NSArray *
_NSCArrayByAddingObjectsFromArray(NSMethodContext const ctx, NSArrayRepresentation const rep,
					NSArray *__unsafe_unretained otherArray)
{
	/* Acquire relevant information about the other array; grab rep info in more convenient variables. */
	Class const c = object_getClass(otherArray);
	id __unsafe_unretained const *const objects = rep.objects;
	NSUInteger const count = rep.count;
	id __unsafe_unretained const *otherObjects;
	NSUInteger otherCount;

	/* Unconditionally copy the other object if we have nothing to add it to. */
	if (count == 0)
		return [otherArray copy];

	/* Decide how we're going to yank the other array's objects out. */
	if (c == _NSZeroArrayClass)
		return rep.isPrivate && rep.arrayCls != _NSMutableInlineArrayClass ? rep.array : [rep.array copy];
	else if (c == _NSSingleEntryArrayClass) {
		otherObjects = &((__bridge NSSingleEntryArrayLayout *)otherArray)->anObject;
		otherCount = 1;
	} else if (c == _NSInlineArrayClass) {
		NSInlineArrayLayout const *const layout = (__bridge NSInlineArrayLayout *)otherArray;
		otherObjects = layout->buffer->objects;
		otherCount = layout->buffer->count;
	} else if (c == _NSMutableInlineArrayClass) {
		NSMutableInlineArrayLayout const *const layout = (__bridge NSMutableInlineArrayLayout *)otherArray;
		otherObjects = layout->buffer->objects;
		otherCount = layout->buffer->count;
	} else if (c == _NSSubrangeArrayClass) {
		NSSubrangeArrayLayout const *const layout = (__bridge NSSubrangeArrayLayout *)otherArray;
		otherObjects = layout->buffer->objects + layout->base;
		otherCount = layout->count;
	} else {
		/* Generic other array. */
		otherObjects = nullptr;
		otherCount = otherArray.count;
	}

	/* If the other array holds nothing, return ourselves as-is, or -copy. */
	if (otherCount == 0)
		return rep.isPrivate && rep.arrayCls != _NSMutableInlineArrayClass ? rep.array : [rep.array copy];

	/* Check the total and allocate a buffer. */
	NSUInteger newCount;
	if (__builtin_add_overflow(count, otherCount, &newCount) || newCount > NSArrayBufferMaximumCount)
		_NSRaiseException(ctx, NSInvalidArgumentException, @"array overflow.");

	NSArrayBuffer *const buffer = NSArrayBufferCreate(newCount);
	buffer->count = newCount;

	/* Copy in our objects using the fastest available method. */
	NSUInteger i = 0;

	if (rep.isPrivate) {
		for (; i < count; ++i)
			buffer->objects[i] = objc_retain(objects[i]);
	} else {
		for (id __unsafe_unretained obj in rep.array) {
			_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, i);
			buffer->objects[i++] = objc_retain(obj);
		}
	}

	/* Copy in the other array's objects using the fastest available method. */
	if (otherObjects != nullptr)
		for (NSUInteger j = 0; j < otherCount; ++j)
			buffer->objects[i++] = objc_retain(otherObjects[j]);
	else {
		for (id __unsafe_unretained obj in otherArray) {
			_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "otherArray", obj, i);
			buffer->objects[i++] = objc_retain(obj);
		}
	}

	return [[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

#define _NSArrayByAddingObjectsFromArray(rep, otherArray) \
	_NSCArrayByAddingObjectsFromArray(MethodContext, (rep), otherArray)

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline NSArray *
_NSCArrayObjectsAtIndexes(NSMethodContext const ctx, NSArrayRepresentation const rep,
				NSIndexSetRepresentation indexSet)
{
	NSUInteger const arrayCount = rep.count;
	NSUInteger const indexSetCount = indexSet.count;
	NSUInteger const rangeCount = indexSet.rangeCount;

	if (indexSetCount == 0)
		return _NSZeroArrayInstance;
	else if (indexSetCount == 1) {
		NSRange const r = indexSet.r.range;
		if (r.location >= arrayCount)
			_NSRaiseException(ctx, NSInvalidArgumentException, @"index set extends beyond array bounds.");

		if (rep.arrayCls == _NSSingleEntryArrayClass)
			return rep.array;

		if (rep.isPrivate)
			return [[NSSingleEntryArray alloc] _initWithObject:rep.objects[r.location]];
		else
			return [[NSSingleEntryArray alloc] _initWithObject:rep.array[r.location]];
	} else if (rangeCount == 1) {
		NSRange const r = indexSet.r.range;
		if (r.location == 0 && r.length == rep.count)
			return rep.isPrivate && rep.arrayCls != _NSMutableInlineArrayClass ?
				rep.array : [rep.array copy];

		if (NSRangeMax(r) > arrayCount)
			_NSRaiseException(ctx, NSInvalidArgumentException, @"index set extends beyond array bounds.");

		if (rep.isPrivate) {
			if (rep.arrayCls == _NSSubrangeArrayClass) {
				NSSubrangeArrayLayout const *const layout =
					(__bridge NSSubrangeArrayLayout *)rep.array;
				return [[NSSubrangeArray alloc]
					_initWithBuffer:(NSArrayBuffer *)(uintptr_t)layout->buffer
						base:layout->base + r.location count:r.length];
			} else {
				/* Immutable and mutable arrays share the same first ivar. */
				NSInlineArrayLayout *const layout =
					(__bridge NSInlineArrayLayout *)rep.array;
				return [[NSSubrangeArray alloc]
					_initWithBuffer:(NSArrayBuffer *)(uintptr_t)layout->buffer
						base:r.location count:r.length];
			}
		} else {
			NSArrayBuffer *const buffer = NSArrayBufferCreate(r.length);
			buffer->count = r.length;

			for (NSUInteger i = r.location, j = 0; i < r.length; ++i, ++j) {
				id __unsafe_unretained obj = rep.array[i];
				_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, i);
				buffer->objects[j] = objc_retain(obj);
			}

			return [[NSInlineArray alloc] _initAdoptingBuffer:buffer];
		}
	}

	/* rangeCount > 1 */
	const NSRange *const ranges = indexSet.r.ranges;
	if (NSRangeMax(ranges[rangeCount - 1]) > arrayCount)
		_NSRaiseException(ctx, NSInvalidArgumentException, @"index set extends beyond array bounds.");

	NSArrayBuffer *const buffer = NSArrayBufferCreate(indexSetCount);
	buffer->count = indexSetCount;

	/* i indexes ranges, j indexes rep objects, k indexes buffer objects. */
	if (rep.isPrivate) {
		for (NSUInteger i = 0, k = 0; i < rangeCount; ++i) {
			NSRange const r = ranges[i];
			for (NSUInteger j = r.location; j < NSRangeMax(r); ++j)
				buffer->objects[k++] = objc_retain(rep.objects[j]);
		}
	} else {
		for (NSUInteger i = 0, k = 0; i < rangeCount; ++i) {
			NSRange const r = ranges[i];
			for (NSUInteger j = r.location; j < NSRangeMax(r); ++j) {
				id __unsafe_unretained obj = rep.array[j];
				_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, j);
				buffer->objects[k++] = objc_retain(obj);
			}
		}
	}

	return [[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

#define _NSArrayObjectsAtIndexes(rep, indexSet) \
	_NSCArrayObjectsAtIndexes(MethodContext, (rep), indexSet)

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline NSUInteger
_NSCArrayIndexOfObjectAtIndexesWithOptionsPassingTest(NSMethodContext const ctx, NSArrayRepresentation const rep,
				NSIndexSetRepresentation indexSet, NSEnumerationOptions options,
				bool (NS_NOESCAPE ^predicate)(id, NSUInteger, bool *))
{
	NSUInteger const arrayCount = rep.count;
	NSUInteger const rangeCount = indexSet.rangeCount;
	NSUInteger const indexSetCount = indexSet.count;
	bool const reverse = options & NSEnumerationReverse;

	if (indexSetCount == 0)
		return NSNotFound;
	else if (indexSetCount == 1) {
		NSUInteger const index = indexSet.r.range.location;
		if (index >= arrayCount)
			_NSRaiseException(ctx, NSInvalidArgumentException, @"index set extends beyond array bounds.");

		id __unsafe_unretained obj;

		if (rep.isPrivate)
			obj = rep.objects[index];
		else {
			obj = rep.array[index];
			_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, index);
		}

		return predicate(obj, index, (bool[]){ false }) == true ? index : NSNotFound;
	}

	/* rangeCount > 1 */
	const NSRange *const ranges = rangeCount == 1 ? (NSRange[]){ indexSet.r.range } : indexSet.r.ranges;
	if (NSRangeMax(ranges[rangeCount - 1]) > arrayCount)
		_NSRaiseException(ctx, NSInvalidArgumentException, @"index set extends beyond array bounds.");

	bool stop = false;

	if (reverse) {
		for (NSUInteger i = rangeCount; i > 0; ) {
			--i;
			NSRange const r = ranges[i];
			for (NSUInteger j = NSRangeMax(r); j > r.location; ) {
				--j;
				id __unsafe_unretained obj;
				if (rep.isPrivate)
					obj = rep.objects[j];
				else {
					obj = rep.array[j];
					_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, j);
				}
				if (predicate(obj, j, &stop) == true)
					return j;

				if (stop == true)
					return NSNotFound;
			}
		}
	} else {
		for (NSUInteger i = 0; i < rangeCount; ++i) {
			NSRange const r = ranges[i];
			for (NSUInteger j = r.location; j < NSRangeMax(r); ++j) {
				id __unsafe_unretained obj;
				if (rep.isPrivate)
					obj = rep.objects[j];
				else {
					obj = rep.array[j];
					_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, j);
				}
				if (predicate(obj, j, &stop) == true)
					return j;

				if (stop == true)
					return NSNotFound;
			}
		}
	}

	return NSNotFound;
}

#define _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(rep, indexSet, options, predicate) \
	_NSCArrayIndexOfObjectAtIndexesWithOptionsPassingTest(MethodContext, (rep), indexSet, options, predicate)

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline NSIndexSet *
_NSCArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(NSMethodContext const ctx, NSArrayRepresentation const rep,
						NSIndexSetRepresentation indexSet, NSEnumerationOptions options,
						bool (NS_NOESCAPE ^predicate)(id, NSUInteger, bool *))
{
	NSUInteger const arrayCount = rep.count;
	NSUInteger const rangeCount = indexSet.rangeCount;
	NSUInteger const indexSetCount = indexSet.count;

	if (indexSetCount == 0)
		return (id)_NSZeroIndexSetInstance;
	else if (indexSetCount == 1) {
		NSUInteger const index = indexSet.r.range.location;
		if (index >= arrayCount)
			_NSRaiseException(ctx, NSInvalidArgumentException, @"index set extends beyond array bounds.");

		id __unsafe_unretained obj;
		if (rep.isPrivate)
			obj = rep.objects[index];
		else {
			obj = rep.array[index];
			_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, index);
		}

		if (predicate(obj, index, (bool[]){ false }) == true) {
			if (indexSet.indexSet == nil)
				return [NSIndexSet indexSetWithIndex:index];
			else
				return indexSet.indexSetCls != _NSMutableInlineIndexSetClass ?
					indexSet.indexSet : [indexSet.indexSet copy];
		}

		return (id)_NSZeroIndexSetInstance;
	}

	/* rangeCount > 1 */
	const NSRange *const ranges = rangeCount == 1 ? (NSRange[]){ indexSet.r.range } : indexSet.r.ranges;
	if (NSRangeMax(ranges[rangeCount - 1]) > arrayCount)
		_NSRaiseException(ctx, NSInvalidArgumentException, @"index set extends beyond array bounds.");

	NSIndexRangeAccumulator acc = {};
	bool stop = false;
	bool const reverse = options & NSEnumerationReverse;

	if (reverse) {
		for (NSUInteger i = rangeCount; i > 0; ) {
			--i;
			NSRange const r = ranges[i];
			for (NSUInteger j = NSRangeMax(r); j > r.location; ) {
				--j;
				id __unsafe_unretained obj;
				if (rep.isPrivate)
					obj = rep.objects[j];
				else {
					obj = rep.array[j];
					_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, j);
				}

				if (predicate(obj, j, &stop) == true)
					_NSIndexRangeAccumulatorAdd(&acc, j, true);
				if (stop == true)
					goto done;
			}
		}
	} else {
		for (NSUInteger i = 0; i < rangeCount; ++i) {
			NSRange const r = ranges[i];
			for (NSUInteger j = r.location; j < NSRangeMax(r); ++j) {
				id __unsafe_unretained obj;
				if (rep.isPrivate)
					obj = rep.objects[j];
				else {
					obj = rep.array[j];
					_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, j);
				}

				if (predicate(obj, j, &stop) == true)
					_NSIndexRangeAccumulatorAdd(&acc, j, false);
				if (stop == true)
					goto done;
			}
		}
	}
done:
	/* Best-effort attempt at not allocating another index set. */
	if (arrayCount == acc.count && rangeCount == acc.rangeCount && indexSet.indexSet != nil) {
		free(acc.ranges);
		/*
		 * We cannot check against nil like in NSIndexSet, as we don't know the input index set's
		 * class at compile-time.
		 */
		return indexSet.indexSetCls != _NSMutableInlineIndexSetClass ?
			indexSet.indexSet : [indexSet.indexSet copy];
	}

	return _NSIndexSetFromAccumulator(&acc, reverse);
}

#define _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(rep, indexSet, options, predicate) \
	_NSCArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(MethodContext, rep, indexSet, options, predicate)

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline void
_NSCArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(NSMethodContext const ctx, NSArrayRepresentation const rep,
						NSIndexSetRepresentation indexSet, NSEnumerationOptions options,
						void (NS_NOESCAPE ^block)(id, NSUInteger, bool *))
{
	NSUInteger const arrayCount = rep.count;
	NSUInteger const rangeCount = indexSet.rangeCount;
	NSUInteger const indexSetCount = indexSet.count;
	bool const reverse = options & NSEnumerationReverse;

	if (indexSetCount == 0)
		return;
	else if (indexSetCount == 1) {
		NSUInteger const index = indexSet.r.range.location;
		if (index >= arrayCount)
			_NSRaiseException(ctx, NSInvalidArgumentException, @"index set extends beyond array bounds.");

		if (rep.isPrivate)
			block(rep.objects[index], index, (bool[]){ false });
		else {
			id __unsafe_unretained obj = rep.array[index];
			_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, index);
			block(obj, index, (bool[]){ false });
		}

		return;
	}

	/* rangeCount > 1 */
	const NSRange *const ranges = rangeCount == 1 ? (NSRange[]){ indexSet.r.range } : indexSet.r.ranges;
	if (NSRangeMax(ranges[rangeCount - 1]) > arrayCount)
		_NSRaiseException(ctx, NSInvalidArgumentException, @"index set extends beyond array bounds.");

	bool stop = false;

	if (reverse) {
		for (NSUInteger i = rangeCount; i > 0; ) {
			--i;
			NSRange const r = ranges[i];
			for (NSUInteger j = NSRangeMax(r); j > r.location; ) {
				j--;
				if (rep.isPrivate)
					block(rep.objects[j], j, &stop);
				else {
					id __unsafe_unretained obj = rep.array[j];
					_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, j);
					block(obj, j, &stop);
				}
				if (stop == true)
					return;
			}
		}
	} else {
		for (NSUInteger i = 0; i < rangeCount; ++i) {
			NSRange const r = ranges[i];
			for (NSUInteger j = r.location; j < NSRangeMax(r); ++j) {
				if (rep.isPrivate)
					block(rep.objects[j], j, &stop);
				else {
					id __unsafe_unretained obj = rep.array[j];
					_NSCForeignArrayRequireNonnilObjectAtIndex(ctx, "self", obj, j);
					block(obj, j, &stop);
				}
				if (stop == true)
					return;
			}
		}
	}
}

#define _NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(rep, indexSet, options, block) \
	_NSCArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(MethodContext, rep, indexSet, options, block)

NS_ASSUME_NONNULL_END

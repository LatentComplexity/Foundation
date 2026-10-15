
#import <FoundationPrivate/NSObject/NSObject.h>
#import <Foundation/NSIndexSet.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Classes

@interface NSIndexSetTemplate : NSIndexSet
@end

@interface NSZeroIndexSet : NSIndexSet
@end

@interface NSSingleEntryIndexSet : NSIndexSet
- (instancetype)_initWithIndex:(NSUInteger)index OBJC_DIRECT;
@end


@interface NSSingleRangeIndexSet : NSIndexSet
- (instancetype)_initWithIndexesInRange:(NSRange)range OBJC_DIRECT;
@end

@interface NSInlineIndexSet : NSIndexSet

- (instancetype)_initWithIndexRanges:(const NSRange *)ranges rangeCount:(NSUInteger)rangeCount
		count:(NSUInteger)count OBJC_DIRECT;

- (instancetype)_initAdoptingIndexRanges:(NSRange *)ranges rangeCount:(NSUInteger)rangeCount
		count:(NSUInteger)count OBJC_DIRECT;

@end

@interface NSMutableIndexSetTemplate : NSMutableIndexSet
@end

@interface NSMutableInlineIndexSet : NSMutableIndexSet

- (instancetype)_initWithIndex:(NSUInteger)index OBJC_DIRECT;

- (instancetype)_initWithIndexesInRange:(NSRange)range OBJC_DIRECT;

- (instancetype)_initWithIndexRanges:(nullable const NSRange *)ranges rangeCount:(NSUInteger)rangeCount
		count:(NSUInteger)count OBJC_DIRECT;

@end

typedef struct [[gnu::may_alias]] NSSingleEntryIndexSetLayout {
	void const *const isa;
	NSUInteger const index;
} NSSingleEntryIndexSetLayout;

typedef struct [[gnu::may_alias]] NSSingleRangeIndexSetLayout {
	void const *const isa;
	NSRange const range;
} NSSingleRangeIndexSetLayout;

typedef struct [[gnu::may_alias]] NSInlineIndexSetLayout {
	void const *const isa;
	NSRange const *const ranges;
	NSUInteger const rangeCount;
	NSUInteger const count;
	NSUInteger const _Atomic _hash;
} NSInlineIndexSetLayout;

typedef struct [[gnu::may_alias]] NSMutableInlineIndexSetLayout {
	void const *const isa;
	NSRange const *const ranges;
	NSUInteger const rangeCount;
	NSUInteger const count;
	NSUInteger const _capacity;
	NSUInteger const _Atomic _hash;
} NSMutableInlineIndexSetLayout;

#pragma mark - Constants

[[gnu::visibility("hidden")]]
extern unsigned __int128 _NSIndexSetHashKey;

[[gnu::visibility("hidden")]]
extern NSUInteger _NSZeroIndexSetHash;

[[gnu::visibility("hidden")]]
extern Class _NSIndexSetClass;

[[gnu::visibility("hidden")]]
extern Class _NSIndexSetTemplateClass;

[[gnu::visibility("hidden")]]
extern Class _NSZeroIndexSetClass;

[[gnu::visibility("hidden")]]
extern Class _NSSingleEntryIndexSetClass;

[[gnu::visibility("hidden")]]
extern Class _NSSingleRangeIndexSetClass;

[[gnu::visibility("hidden")]]
extern Class _NSInlineIndexSetClass;

[[gnu::visibility("hidden")]]
extern Class _NSMutableIndexSetClass;

[[gnu::visibility("hidden")]]
extern Class _NSMutableIndexSetTemplateClass;

[[gnu::visibility("hidden")]]
extern Class _NSMutableInlineIndexSetClass;

[[gnu::visibility("hidden")]]
extern NSZeroIndexSet *_NSZeroIndexSetInstance;

#pragma mark - Validation

#define NSIndexSetMaximumIndex ((NSUInteger)NSNotFound - 1)

#define _NSIndexSetRequireIndexBelowMaximum(idx) \
	if (idx > NSIndexSetMaximumIndex) \
		_NSRaiseException(MethodContext, NSInvalidArgumentException, \
			@"'%s' exceeds maximum representable index.", #idx)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCIndexSetRejectReinitialization(NSMethodContext const ctx)
{
	_NSClusterRejectReinitialization(ctx, _NSIndexSetClass,
		(NSClassSpan) {
			.classes = (Class[]){ _NSZeroIndexSetClass, _NSSingleEntryIndexSetClass,
						_NSSingleRangeIndexSetClass, _NSInlineIndexSetClass },
			.count = 4
		}, _NSSubclassingForbidden);
}

#define _NSIndexSetRejectReinitialization() \
	_NSCIndexSetRejectReinitialization(MethodContext)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCIndexSetRejectInvocation(NSMethodContext const ctx)
{
	_NSClusterRejectInvocation(ctx, _NSIndexSetClass, _NSIndexSetTemplateClass, _NSSubclassingForbidden);
}

#define _NSIndexSetRejectInvocation() \
	_NSCIndexSetRejectInvocation(MethodContext)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCMutableIndexSetRejectReinitialization(NSMethodContext const ctx)
{
	_NSClusterRejectReinitialization(ctx, _NSIndexSetClass,
		(NSClassSpan) {
			.classes = (Class[]){ _NSMutableInlineIndexSetClass },
			.count = 1
		}, _NSSubclassingForbidden);
}

#define _NSMutableIndexSetRejectReinitialization() \
	_NSCMutableIndexSetRejectReinitialization(MethodContext)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCMutableIndexSetRejectInvocation(NSMethodContext const ctx)
{
	_NSClusterRejectInvocation(ctx, _NSMutableIndexSetClass, _NSMutableIndexSetTemplateClass,
					_NSSubclassingForbidden);
}

#define _NSMutableIndexSetRejectInvocation() \
	_NSCMutableIndexSetRejectInvocation(MethodContext)

#pragma mark - Generics

/* Canonicalize an index set. r.ranges is invalid if rangeCount < 2. */
typedef struct NSIndexSetRepresentation {
	NSIndexSet *__unsafe_unretained indexSet;
	Class indexSetCls;
	union {
		NSRange range;
		const NSRange *ranges;
	} r;
	NSUInteger rangeCount;
	NSUInteger count;
} NSIndexSetRepresentation;

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline NSIndexSetRepresentation
_NSIndexSetGetRepresentation(NSIndexSet *indexSet)
{
	NSIndexSetRepresentation rep = {};
	Class const c = object_getClass(indexSet);
	rep.indexSet = indexSet;
	rep.indexSetCls = c;

	if (c == _NSZeroIndexSetClass) {
		rep.r.ranges = nullptr;
		rep.rangeCount = 0;
		rep.count = 0;
	} else if (c == _NSSingleEntryIndexSetClass) {
		NSUInteger const index = ((__bridge NSSingleEntryIndexSetLayout *)indexSet)->index;
		rep.r.range = NSRangeMake(index, 1);
		rep.rangeCount = 1;
		rep.count = 1;
	} else if (c == _NSSingleRangeIndexSetClass) {
		rep.r.range = ((__bridge NSSingleRangeIndexSetLayout *)indexSet)->range;
		rep.rangeCount = 1;
		rep.count = rep.r.range.length;
	} else if (c == _NSInlineIndexSetClass) {
		NSInlineIndexSetLayout const *const layout = (__bridge NSInlineIndexSetLayout *)indexSet;
		rep.r.ranges = layout->ranges;
		rep.rangeCount = layout->rangeCount;
		rep.count = layout->count;
	} else if (c == _NSMutableInlineIndexSetClass) {
		NSMutableInlineIndexSetLayout const *const layout = (__bridge NSMutableInlineIndexSetLayout *)indexSet;
		if (layout->rangeCount == 0) {
			rep.r.ranges = nullptr;
			rep.rangeCount = 0;
			rep.count = 0;
		} else if (layout->rangeCount == 1) {
			rep.r.range = layout->ranges[0];
			rep.rangeCount = 1;
			rep.count = rep.r.range.length;
		} else {
			rep.r.ranges = layout->ranges;
			rep.rangeCount = layout->rangeCount;
			rep.count = layout->count;
		}
	} else
		__builtin_trap();

	return rep;
}

typedef struct NSIndexRangeAccumulator {
	NSRange *_Nullable ranges;
	NSUInteger rangeCount;
	NSUInteger count;
	NSUInteger capacity;
} NSIndexRangeAccumulator;

[[clang::always_inline]]
static inline void
_NSIndexRangeAccumulatorAdd(NSIndexRangeAccumulator *acc, NSUInteger index, bool isDescending)
{
	/* Callers supply distinct valid indices in strict traversal order from a concrete index set. */
	if (acc->rangeCount > 0) {
		NSRange *const last = &acc->ranges[acc->rangeCount - 1];

		/* Fold into the open run when this index is adjacent to it in the direction of travel. */
		if (isDescending && index + 1 == last->location) {
			last->location = index;
			last->length += 1;
			++acc->count;
			return;
		}

		if (index == NSRangeMax(*last)) {
			last->length += 1;
			++acc->count;
			return;
		}
	}

	if (acc->rangeCount == acc->capacity) {
		NSUInteger newCapacity;
		NSUInteger byteCapacity;

		/* Grow geometrically so a run of appends amortizes to O(1) per range. */
		if (acc->capacity == 0)
			newCapacity = 4;
		else
			newCapacity = acc->capacity * 2;

		/* The range count fits in NSUInteger, but the corresponding byte allocation need not. */
		if (__builtin_mul_overflow(newCapacity, sizeof(NSRange), &byteCapacity))
			[NSException raise:NSMallocException format:@"%s: failed to grow index range list.",
				__PRETTY_FUNCTION__];

		void *const grown = realloc(acc->ranges, byteCapacity);
		if (grown == nullptr)
			[NSException raise:NSMallocException format:@"%s: failed to grow index range list.",
				__PRETTY_FUNCTION__];

		acc->ranges = grown;
		acc->capacity = newCapacity;
	}

	acc->ranges[acc->rangeCount++] = NSRangeMake(index, 1);
	++acc->count;
}

[[clang::always_inline]]
static inline NSIndexSet *
_NSIndexSetFromAccumulator(NSIndexRangeAccumulator *const acc, bool isDescending)
{
	if (isDescending && acc->rangeCount > 1) {
		NSUInteger start = 0;
		NSUInteger end = acc->rangeCount - 1;

		while (start < end) {
			NSRange const temp = acc->ranges[start];
			acc->ranges[start] = acc->ranges[end];
			acc->ranges[end] = temp;
			++start;
			--end;
		}
	}

	if (acc->rangeCount == 0) {
		free(acc->ranges);
		return _NSZeroIndexSetInstance;
	} else if (acc->rangeCount == 1) {
		NSIndexSet *result;

		if (acc->ranges[0].length == 1)
			result = [[NSSingleEntryIndexSet alloc] _initWithIndex:acc->ranges[0].location];
		else
			result = [[NSSingleRangeIndexSet alloc] _initWithIndexesInRange:acc->ranges[0]];

		free(acc->ranges);
		return result;
	} else
		return [[NSInlineIndexSet alloc] _initAdoptingIndexRanges:(NSRange *_Nonnull)acc->ranges
			rangeCount:acc->rangeCount count:acc->count];
}

/* TODO: shared iterator, index, and index set methods. */

/*
 * Binary search the many-range buffer for the range covering anIndex. On a hit, return its slot with
 * *isContained = true. On a miss, return the slot of the first range located entirely above the index within
 * [0, rangeCount].
 */
[[clang::always_inline]]
static inline NSUInteger
_NSIndexSetRangeSlotForIndex(NSRange const *const ranges, NSUInteger const rangeCount, NSUInteger const anIndex,
				bool *const isContained)
{
	NSUInteger lo = 0;
	NSUInteger hi = rangeCount;

	while (lo < hi) {
		NSUInteger const mid = lo + (hi - lo) / 2;

		if (anIndex < ranges[mid].location)
			hi = mid;
		else if (anIndex >= NSRangeMax(ranges[mid]))
			lo = mid + 1;
		else {
			*isContained = true;
			return mid;
		}
	}

	*isContained = false;
	return lo;
}

/* Requires r.ranges to be valid, along with rangeCount and count. */
[[clang::always_inline]]
static inline NSUInteger
_NSCIndexSetGetIndexesInRange(NSMethodContext ctx, NSIndexSetRepresentation const rep, NSUInteger *const indexBuffer,
				NSUInteger const bufferSize, NSRange *const _Nullable rangePointer)
{
	NSRange desiredClampRange;

	/* Validate all potential input first, then return if caller has no more buffer room. */
	if (rangePointer != nil)
		_NSCRangeWithinUpperBound(ctx, desiredClampRange = *rangePointer, (NSUInteger)NSNotFound,
						"rangePointer");

	if (bufferSize == 0 || rep.count == 0)
		return 0;

	NSRange clamp;
	NSUInteger filled = 0;
	NSUInteger lastEmitted = 0;
	NSRange const *const ranges = rep.r.ranges;
	NSUInteger rangeCount = rep.rangeCount;

	/* Clamp to desired bounds if specified, otherwise run across the whole index set. */
	if (rangePointer != nil) {
		if (desiredClampRange.length == 0)
			return 0;
		clamp = desiredClampRange;
	} else
		clamp = NSRangeMake(ranges[0].location, NSRangeMax(ranges[rangeCount - 1]) - ranges[0].location);

	NSUInteger firstRange = 0;

	/* Find the first range at which to start iterating. */
	if (rangePointer != nil)
		firstRange = _NSIndexSetRangeSlotForIndex(ranges, rangeCount, clamp.location, (bool[]){ false });

	for (NSUInteger r = firstRange; r < rangeCount && filled < bufferSize; ++r) {
		NSRange const section = NSRangeIntersection(ranges[r], clamp);

		for (NSUInteger i = section.location, end = NSRangeMax(section); i < end && filled < bufferSize; ++i) {
			indexBuffer[filled++] = i;
			lastEmitted = i;
		}
	}

	/* Advance the caller's cursor past the last index copied. */
	if (rangePointer != nil && filled > 0)
		*rangePointer = NSRangeMake(lastEmitted + 1, NSRangeMax(clamp) - (lastEmitted + 1));

	return filled;
}

#define _NSIndexSetGetIndexesInRange(rep, indexBuffer, bufferSize, rangePointer) \
	_NSCIndexSetGetIndexesInRange(MethodContext, (rep), indexBuffer, bufferSize, rangePointer)

[[clang::always_inline]]
static inline bool
_NSIndexSetContainsIndexes(NSIndexSetRepresentation const rep, NSIndexSet *__unsafe_unretained indexSet)
{
	Class const c = object_getClass(indexSet);

	/* We hold nothing and can only ever contain nothing. */
	if (rep.count == 0)
		return c == _NSZeroIndexSetClass;

	/* Everything else by default contains nothing. */
	if (c == _NSZeroIndexSetClass)
		return true;

	NSRange const *const ranges = rep.r.ranges;

	/* We hold a single index. */
	if (rep.count == 1) {
		if (c == _NSSingleEntryIndexSetClass)
			return ranges[0].location == ((__bridge NSSingleEntryIndexSetLayout *)indexSet)->index;
		else if (c == _NSMutableInlineIndexSetClass) {
			NSMutableInlineIndexSetLayout const *const layout =
				(__bridge NSMutableInlineIndexSetLayout *)indexSet;
			NSUInteger const otherIndex = layout->ranges[0].location;
			return layout->count == 0 || (layout->count == 1 && ranges[0].location == otherIndex);
		}

		return false;
	}

	NSUInteger const rangeCount = rep.rangeCount;

	/* We hold a single range. */
	if (rangeCount == 1) {
		if (c == _NSSingleEntryIndexSetClass) {
			NSUInteger const otherIndex = ((__bridge NSSingleEntryIndexSetLayout *)indexSet)->index;
			return otherIndex >= ranges[0].location && otherIndex < NSRangeMax(ranges[0]);
		} else if (c == _NSSingleRangeIndexSetClass) {
			NSRange const otherRange = ((__bridge NSSingleRangeIndexSetLayout *)indexSet)->range;
			return NSRangeEqualToRange(NSRangeUnion(ranges[0], otherRange), ranges[0]);
		} else if (c == _NSInlineIndexSetClass || c == _NSMutableInlineIndexSetClass) {
			NSInlineIndexSetLayout const *const layout = (__bridge NSInlineIndexSetLayout *)indexSet;

			if (layout->count == 0)
				return true;

			return layout->ranges[0].location >= ranges[0].location &&
				NSRangeMax(layout->ranges[layout->rangeCount - 1]) <= NSRangeMax(ranges[0]);
		}

		return false;
	}

	/* We hold multiple ranges. */

	if (c == _NSSingleEntryIndexSetClass) {
		bool isContained = false;
		NSUInteger const otherIndex = ((__bridge NSSingleEntryIndexSetLayout *)indexSet)->index;
		(void)_NSIndexSetRangeSlotForIndex(ranges, rangeCount, otherIndex, &isContained);
		return isContained;
	}

	if (c == _NSSingleRangeIndexSetClass) {
		bool isContained = false;
		NSRange const otherRange = ((__bridge NSSingleRangeIndexSetLayout *)indexSet)->range;
		NSUInteger const slot = _NSIndexSetRangeSlotForIndex(ranges, rangeCount, otherRange.location,
									&isContained);
		if (isContained == false)
			return false;
		return NSRangeMax(otherRange) <= NSRangeMax(ranges[slot]);
	}

	if (c == _NSInlineIndexSetClass || c == _NSMutableInlineIndexSetClass) {
		/* This is fine. Both classes keep the same ivars up top. */
		NSInlineIndexSetLayout const *const layout = (__bridge NSInlineIndexSetLayout *)indexSet;
		NSUInteger r = 0;

		if (layout->count > rep.count)
			return false;

		/* TODO: I wonder if there's a better algorithm. */
		for (NSUInteger i = 0; i < layout->rangeCount; ++i) {
			while (r < rangeCount && NSRangeMax(ranges[r]) <= layout->ranges[i].location)
				++r;

			if (r == rangeCount || layout->ranges[i].location < ranges[r].location ||
			    NSRangeMax(layout->ranges[i]) > NSRangeMax(ranges[r]))
				return false;
		}

		return true;
	}

	__builtin_trap();
}

[[clang::always_inline]]
static inline NSUInteger
_NSIndexSetIndexInRangeWithOptionsPassingTest(NSIndexSetRepresentation const rep, NSRange const range,
				NSEnumerationOptions options, bool (NS_NOESCAPE ^predicate)(NSUInteger, bool *))
{
	bool stop = false;
	NSRange const *const ranges = rep.r.ranges;
	NSUInteger const rangeCount = rep.rangeCount;

	if (options & NSEnumerationReverse) {
		for (NSUInteger i = rangeCount; i > 0;) {
			--i;
			NSRange const section = NSRangeIntersection(ranges[i], range);

			if (section.length == 0)
				continue;

			for (NSUInteger j = NSRangeMax(section); j > section.location;) {
				--j;
				if (predicate(j, &stop) == true)
					return j;
				if (stop == true)
					return NSNotFound;
			}
		}
	} else {
		for (NSUInteger i = 0; i < rangeCount; ++i) {
			NSRange const section = NSRangeIntersection(ranges[i], range);

			if (section.length == 0)
				continue;

			for (NSUInteger j = section.location; j < NSRangeMax(section); ++j) {
				if (predicate(j, &stop) == true)
					return j;
				if (stop == true)
					return NSNotFound;
			}
		}
	}

	return NSNotFound;
}

[[clang::always_inline]]
static inline NSIndexSet *
_NSIndexSetIndexesInRangeWithOptionsPassingTest(NSIndexSetRepresentation const rep, NSRange const range,
				NSEnumerationOptions options, bool (NS_NOESCAPE ^predicate)(NSUInteger, bool *))
{
	NSIndexRangeAccumulator acc = {};
	bool stop = false;
	bool const reverse = (options & NSEnumerationReverse) != 0;
	NSRange const *const ranges = rep.r.ranges;
	NSUInteger const rangeCount = rep.rangeCount;

	if (reverse) {
		for (NSUInteger i = rangeCount; i > 0;) {
			--i;
			NSRange const section = NSRangeIntersection(ranges[i], range);

			if (section.length == 0)
				continue;

			for (NSUInteger j = NSRangeMax(section); j > section.location;) {
				--j;
				if (predicate(j, &stop) == true)
					_NSIndexRangeAccumulatorAdd(&acc, j, true);
				if (stop == true)
					goto manyDone;
			}
		}
	} else {
		for (NSUInteger i = 0; i < rangeCount; ++i) {
			NSRange const section = NSRangeIntersection(ranges[i], range);

			if (section.length == 0)
				continue;

			for (NSUInteger j = section.location; j < NSRangeMax(section); ++j) {
				if (predicate(j, &stop) == true)
					_NSIndexRangeAccumulatorAdd(&acc, j, false);
				if (stop == true)
					goto manyDone;
			}
		}
	}

manyDone:
	if (rangeCount == acc.rangeCount && rep.count == acc.count) {
		/* Immutable sources return themselves; mutable sources return an immutable snapshot. */
		free(acc.ranges);
		return rep.indexSetCls == nil ? rep.indexSet : [rep.indexSet copy];
	}

	return _NSIndexSetFromAccumulator(&acc, reverse);
}

[[clang::always_inline]]
static inline void
_NSIndexSetEnumerateIndexesInRangeWithOptionsUsingBlock(NSIndexSetRepresentation const rep, NSRange const range,
				NSEnumerationOptions options, void (NS_NOESCAPE ^block)(NSUInteger, bool *))
{
	bool stop = false;
	NSRange const *const ranges = rep.r.ranges;
	NSUInteger const rangeCount = rep.rangeCount;

	if (options & NSEnumerationReverse) {
		for (NSUInteger i = rangeCount; i > 0;) {
			--i;
			NSRange const section = NSRangeIntersection(ranges[i], range);

			if (section.length == 0)
				continue;

			for (NSUInteger j = NSRangeMax(section); j > section.location;) {
				--j;
				block(j, &stop);
				if (stop == true)
					return;
			}
		}
	} else {
		for (NSUInteger i = 0; i < rangeCount; ++i) {
			NSRange const section = NSRangeIntersection(ranges[i], range);

			if (section.length == 0)
				continue;

			for (NSUInteger j = section.location; j < NSRangeMax(section); ++j) {
				block(j, &stop);
				if (stop == true)
					return;
			}
		}
	}
}

[[clang::always_inline]]
static inline void
_NSIndexSetEnumerateRangesInRangeWithOptionsUsingBlock(NSIndexSetRepresentation const rep, NSRange const range,
				NSEnumerationOptions options, void (NS_NOESCAPE ^block)(NSRange, bool *))
{
	bool stop = false;
	NSRange const *const ranges = rep.r.ranges;
	NSUInteger const rangeCount = rep.rangeCount;

	if (options & NSEnumerationReverse) {
		for (NSUInteger i = rangeCount; i > 0;) {
			--i;
			NSRange const section = NSRangeIntersection(ranges[i], range);

			if (section.length == 0)
				continue;

			block(section, &stop);
			if (stop == true)
				return;
		}
	} else {
		for (NSUInteger i = 0; i < rangeCount; ++i) {
			NSRange const section = NSRangeIntersection(ranges[i], range);

			if (section.length == 0)
				continue;

			block(section, &stop);
			if (stop == true)
				return;
		}
	}
}

NS_ASSUME_NONNULL_END

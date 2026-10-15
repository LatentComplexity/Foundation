
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSException.h>

typedef struct _NSRange {
	NSUInteger location;
	NSUInteger length;
} NSRange;

#define NSRangeZero (NSRange){0UL, 0UL}

[[clang::always_inline]]
static inline NSRange
NSRangeMake(NSUInteger location, NSUInteger length)
{
	return (NSRange){ location, length };
}

[[clang::always_inline]]
static inline bool
NSRangeEqualToRange(NSRange aRange, NSRange otherRange)
{
	return aRange.location == otherRange.location && aRange.length == otherRange.length;
}

[[clang::always_inline]]
[[clang::no_sanitize("integer")]]
static inline NSUInteger
NSRangeMax(NSRange aRange)
{
	return aRange.location + aRange.length;
}

[[clang::always_inline]]
static inline bool
NSRangeContainsLocation(NSRange aRange, NSUInteger location)
{
	return location >= aRange.location && location < NSRangeMax(aRange);
}

/*
 * Disjoint points and ranges are always represented by NSRangeZero. Overlapping points return the point with a length
 * of zero. Overlapping ranges return the range. Intersecting ranges return the intersection with a length > 1.
 *
 * Caveat: an intersection of 0, 0 and 0, 0 will return 0, 0; this is both the answer and the representation of
 * disjointedness.
 */
static inline NSRange
NSRangeIntersection(NSRange aRange, NSRange otherRange)
{
	NSUInteger const start = MAX(aRange.location, otherRange.location);
	NSUInteger const end = MIN(NSRangeMax(aRange), NSRangeMax(otherRange));

	/* Check for points first. */
	if (aRange.length == 0 && otherRange.length == 0) {
		/* Intersection of two equal points is the point itself. */
		if (aRange.location == otherRange.location)
			return (NSRange){ aRange.location, 0 };

		/* Disjoint points. */
		return NSRangeZero;
	}

	/* Check for ranges; if they intersect at a point, return it. */
	if (end == start)
		return (NSRange){ start, 0 };

	if (end < start)
		return NSRangeZero;

	return (NSRange){ start, end - start };
}

/*
 * A union of two ranges covers all indices in and between aRange and otherRange. The union of two points is defined
 * as the range of indices between them. Same for a point and a range, or two ranges.
 */
[[clang::always_inline]]
static inline NSRange
NSRangeUnion(NSRange aRange, NSRange otherRange)
{
	NSUInteger const min = MIN(aRange.location, otherRange.location);
	NSUInteger const max = MAX(NSRangeMax(aRange), NSRangeMax(otherRange));

	return (NSRange){ min, max - min };
}

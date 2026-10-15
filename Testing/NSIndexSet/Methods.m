#import <Foundation/NSIndexSet.h>
#import "Test.h"

#import <objc/runtime.h>

#include <stdatomic.h>
#include <string.h>

enum {
	FixtureCount = 4,
	MaximumFixtureMembers = 8,
	QueryUpperBound = 17
};

typedef struct IndexSetFixture {
	__unsafe_unretained NSIndexSet *set;
	char const *className;
	NSUInteger const *members;
	NSUInteger count;
} IndexSetFixture;

static NSIndexSet *
ManyIndexSet(void)
{
	NSMutableIndexSet *builder = [NSMutableIndexSet indexSet];

	[builder addIndexesInRange:NSRangeMake(1, 2)];
	[builder addIndexesInRange:NSRangeMake(7, 2)];
	[builder addIndexesInRange:NSRangeMake(12, 3)];

	return [builder copy];
}

static NSIndexSet *
IndexSetWithMembers(NSUInteger const *members, NSUInteger count)
{
	NSMutableIndexSet *builder = [NSMutableIndexSet indexSet];

	for (NSUInteger i = 0; i < count; ++i)
		[builder addIndex:members[i]];

	return [builder copy];
}

static bool
ReferenceContainsIndex(IndexSetFixture const *fixture, NSUInteger index)
{
	for (NSUInteger i = 0; i < fixture->count; ++i)
		if (fixture->members[i] == index)
			return true;

	return false;
}

static NSUInteger
ReferenceCountInRange(IndexSetFixture const *fixture, NSRange range)
{
	NSUInteger count = 0;
	NSUInteger const upperBound = NSRangeMax(range);

	for (NSUInteger i = 0; i < fixture->count; ++i)
		if (fixture->members[i] >= range.location && fixture->members[i] < upperBound)
			++count;

	return count;
}

static bool
ReferenceContainsRange(IndexSetFixture const *fixture, NSRange range)
{
	return range.length != 0 && ReferenceCountInRange(fixture, range) == range.length;
}

static bool
ReferenceIntersectsRange(IndexSetFixture const *fixture, NSRange range)
{
	return ReferenceCountInRange(fixture, range) != 0;
}

static NSUInteger
ReferenceGreater(IndexSetFixture const *fixture, NSUInteger index, bool orEqual)
{
	for (NSUInteger i = 0; i < fixture->count; ++i)
		if (fixture->members[i] > index || (orEqual && fixture->members[i] == index))
			return fixture->members[i];

	return NSNotFound;
}

static NSUInteger
ReferenceLess(IndexSetFixture const *fixture, NSUInteger index, bool orEqual)
{
	for (NSUInteger i = fixture->count; i > 0;) {
		--i;
		if (fixture->members[i] < index || (orEqual && fixture->members[i] == index))
			return fixture->members[i];
	}

	return NSNotFound;
}

static bool
ReferenceIsSubset(IndexSetFixture const *receiver, IndexSetFixture const *argument)
{
	for (NSUInteger i = 0; i < argument->count; ++i)
		if (!ReferenceContainsIndex(receiver, argument->members[i]))
			return false;

	return true;
}

static bool
ReferenceIsEqual(IndexSetFixture const *a, IndexSetFixture const *b)
{
	if (a->count != b->count)
		return false;

	for (NSUInteger i = 0; i < a->count; ++i)
		if (a->members[i] != b->members[i])
			return false;

	return true;
}

static NSUInteger
ReferenceFilteredMembers(IndexSetFixture const *fixture, NSRange range, bool evensOnly,
	NSUInteger *members)
{
	NSUInteger count = 0;
	NSUInteger const upperBound = NSRangeMax(range);

	for (NSUInteger i = 0; i < fixture->count; ++i) {
		NSUInteger const index = fixture->members[i];

		if (index >= range.location && index < upperBound && (!evensOnly || index % 2 == 0))
			members[count++] = index;
	}

	return count;
}

static NSUInteger
ReferenceRanges(IndexSetFixture const *fixture, NSRange limit, NSRange *ranges)
{
	NSUInteger members[MaximumFixtureMembers];
	NSUInteger const memberCount = ReferenceFilteredMembers(fixture, limit, false, members);
	NSUInteger rangeCount = 0;

	for (NSUInteger i = 0; i < memberCount; ++i) {
		if (rangeCount > 0 && NSRangeMax(ranges[rangeCount - 1]) == members[i])
			++ranges[rangeCount - 1].length;
		else
			ranges[rangeCount++] = NSRangeMake(members[i], 1);
	}

	return rangeCount;
}

static char const *
ReferenceClassName(NSUInteger const *members, NSUInteger count)
{
	if (count == 0)
		return "NSZeroIndexSet";

	if (count == 1)
		return "NSSingleEntryIndexSet";

	for (NSUInteger i = 1; i < count; ++i)
		if (members[i] != members[i - 1] + 1)
			return "NSInlineIndexSet";

	return "NSSingleRangeIndexSet";
}

static void
TestMembers(NSIndexSet *set, NSUInteger const *expected, NSUInteger expectedCount)
{
	NSUInteger actual[MaximumFixtureMembers] = { 0 };
	NSUInteger const copied = [set getIndexes:actual maxCount:MaximumFixtureMembers
		inIndexRange:nullptr];

	TEST_EQ_UNSIGNED(set.count, expectedCount);
	TEST_EQ_UNSIGNED(copied, expectedCount);
	TEST_STR_EQ(object_getClassName(set), ReferenceClassName(expected, expectedCount));

	for (NSUInteger i = 0; i < expectedCount; ++i)
		TEST_EQ_UNSIGNED(actual[i], expected[i]);

	if (expectedCount == 0) {
		TEST_EQ_UNSIGNED(set.firstIndex, NSNotFound);
		TEST_EQ_UNSIGNED(set.lastIndex, NSNotFound);
	} else {
		TEST_EQ_UNSIGNED(set.firstIndex, expected[0]);
		TEST_EQ_UNSIGNED(set.lastIndex, expected[expectedCount - 1]);
	}
}

static void
TestPropertiesAndIdentity(IndexSetFixture const *fixtures)
{
	for (NSUInteger i = 0; i < FixtureCount; ++i) {
		IndexSetFixture const *fixture = &fixtures[i];
		NSUInteger const first = fixture->count == 0 ? NSNotFound : fixture->members[0];
		NSUInteger const last = fixture->count == 0 ? NSNotFound : fixture->members[fixture->count - 1];
		NSUInteger const firstHash = fixture->set.hash;
		NSMutableIndexSet *mutableEqual = [fixture->set mutableCopy];
		NSIndexSet *immutableEqual = [mutableEqual copy];

		TEST_STR_EQ(object_getClassName(fixture->set), fixture->className);
		TEST_EQ_UNSIGNED(fixture->set.count, fixture->count);
		TEST_EQ_UNSIGNED(fixture->set.firstIndex, first);
		TEST_EQ_UNSIGNED(fixture->set.lastIndex, last);
		TEST_EQ_UNSIGNED(fixture->set.hash, firstHash);
		TEST_EQ_UNSIGNED(fixture->set.hash, firstHash);
		TEST([fixture->set isEqualToIndexSet:fixture->set]);
		TEST([fixture->set isEqual:fixture->set]);
		TEST(![fixture->set isEqual:nil]);
		TEST(![fixture->set isEqual:@"not an index set"]);

		TEST((id)mutableEqual != (id)fixture->set);
		TEST([fixture->set isEqualToIndexSet:mutableEqual]);
		TEST([mutableEqual isEqualToIndexSet:fixture->set]);
		TEST([fixture->set isEqual:mutableEqual]);
		TEST([mutableEqual isEqual:fixture->set]);
		TEST_EQ_UNSIGNED(fixture->set.hash, mutableEqual.hash);

		TEST([fixture->set isEqualToIndexSet:immutableEqual]);
		TEST([immutableEqual isEqualToIndexSet:fixture->set]);
		TEST_EQ_UNSIGNED(fixture->set.hash, immutableEqual.hash);
	}
}

static void
TestPairwiseSetMethods(IndexSetFixture const *fixtures)
{
	for (NSUInteger receiver = 0; receiver < FixtureCount; ++receiver) {
		for (NSUInteger argument = 0; argument < FixtureCount; ++argument) {
			bool const subset = ReferenceIsSubset(&fixtures[receiver], &fixtures[argument]);
			bool const equal = ReferenceIsEqual(&fixtures[receiver], &fixtures[argument]);

			TEST_EQ([fixtures[receiver].set containsIndexes:fixtures[argument].set], subset);
			TEST_EQ([fixtures[receiver].set isEqualToIndexSet:fixtures[argument].set], equal);
			TEST_EQ([fixtures[receiver].set isEqual:fixtures[argument].set], equal);
		}
	}
}

static void
TestContainmentCase(NSIndexSet *receiver, NSIndexSet *argument, bool expected)
{
	NSMutableIndexSet *mutableArgument = [argument mutableCopy];

	TEST_EQ([receiver containsIndexes:argument], expected);
	TEST_EQ([receiver containsIndexes:mutableArgument], expected);
}

static void
TestAdditionalContainmentCases(IndexSetFixture const *fixtures)
{
	NSIndexSet *zero = fixtures[0].set;
	NSIndexSet *single = fixtures[1].set;
	NSIndexSet *range = fixtures[2].set;
	NSIndexSet *many = fixtures[3].set;
	NSIndexSet *singleInsideRange = [NSIndexSet indexSetWithIndex:6];
	NSIndexSet *singleOutsideRange = [NSIndexSet indexSetWithIndex:10];
	NSIndexSet *rangeInsideRange = [NSIndexSet indexSetWithIndexesInRange:NSRangeMake(6, 3)];
	NSIndexSet *rangeCrossingRange = [NSIndexSet indexSetWithIndexesInRange:NSRangeMake(8, 3)];
	NSIndexSet *rangeInsideMany = [NSIndexSet indexSetWithIndexesInRange:NSRangeMake(12, 3)];
	NSIndexSet *rangeCrossingMany = [NSIndexSet indexSetWithIndexesInRange:NSRangeMake(2, 6)];
	NSIndexSet *manyInsideRange = IndexSetWithMembers((NSUInteger[]){ 5, 7, 9 }, 3);
	NSIndexSet *manyCrossingRange = IndexSetWithMembers((NSUInteger[]){ 5, 7, 10 }, 3);
	NSIndexSet *manyInsideMany = IndexSetWithMembers((NSUInteger[]){ 1, 7, 12, 14 }, 4);
	NSIndexSet *manyOutsideMany = IndexSetWithMembers((NSUInteger[]){ 1, 7, 15 }, 3);

	TestContainmentCase(zero, zero, true);
	TestContainmentCase(zero, single, false);
	TestContainmentCase(zero, range, false);
	TestContainmentCase(zero, many, false);

	TestContainmentCase(single, zero, true);
	TestContainmentCase(single, single, true);
	TestContainmentCase(single, singleInsideRange, false);
	TestContainmentCase(single, range, false);
	TestContainmentCase(single, many, false);

	TestContainmentCase(range, zero, true);
	TestContainmentCase(range, singleInsideRange, true);
	TestContainmentCase(range, singleOutsideRange, false);
	TestContainmentCase(range, rangeInsideRange, true);
	TestContainmentCase(range, rangeCrossingRange, false);
	TestContainmentCase(range, manyInsideRange, true);
	TestContainmentCase(range, manyCrossingRange, false);

	TestContainmentCase(many, zero, true);
	TestContainmentCase(many, single, true);
	TestContainmentCase(many, singleInsideRange, false);
	TestContainmentCase(many, rangeInsideMany, true);
	TestContainmentCase(many, rangeCrossingMany, false);
	TestContainmentCase(many, manyInsideMany, true);
	TestContainmentCase(many, manyOutsideMany, false);
}

static void
TestGetIndexes(IndexSetFixture const *fixtures)
{
	for (NSUInteger f = 0; f < FixtureCount; ++f) {
		IndexSetFixture const *fixture = &fixtures[f];

		for (NSUInteger capacity = 0; capacity <= MaximumFixtureMembers; ++capacity) {
			NSUInteger buffer[MaximumFixtureMembers + 1];
			NSUInteger const expectedCount = MIN(fixture->count, capacity);
			NSUInteger copied;

			for (NSUInteger i = 0; i < MaximumFixtureMembers + 1; ++i)
				buffer[i] = 0xfeed;

			copied = [fixture->set getIndexes:buffer maxCount:capacity inIndexRange:nullptr];
			TEST_EQ_UNSIGNED(copied, expectedCount);
			for (NSUInteger i = 0; i < expectedCount; ++i)
				TEST_EQ_UNSIGNED(buffer[i], fixture->members[i]);
			TEST_EQ_UNSIGNED(buffer[expectedCount], 0xfeed);
		}

		for (NSUInteger location = 0; location <= QueryUpperBound; ++location) {
			for (NSUInteger length = 0; length <= QueryUpperBound - location; ++length) {
				NSRange const original = NSRangeMake(location, length);

				for (NSUInteger capacity = 0; capacity <= 4; ++capacity) {
					NSUInteger buffer[5] = { 0xfeed, 0xfeed, 0xfeed, 0xfeed, 0xfeed };
					NSUInteger expected[MaximumFixtureMembers];
					NSUInteger expectedCount = ReferenceFilteredMembers(fixture, original, false, expected);
					NSRange cursor = original;
					NSUInteger copied;

					if (expectedCount > capacity)
						expectedCount = capacity;

					copied = [fixture->set getIndexes:buffer maxCount:capacity inIndexRange:&cursor];
					TEST_EQ_UNSIGNED(copied, expectedCount);
					for (NSUInteger i = 0; i < expectedCount; ++i)
						TEST_EQ_UNSIGNED(buffer[i], expected[i]);
					TEST_EQ_UNSIGNED(buffer[expectedCount], 0xfeed);

					if (expectedCount == 0) {
						TEST_EQ_UNSIGNED(cursor.location, original.location);
						TEST_EQ_UNSIGNED(cursor.length, original.length);
					} else {
						NSUInteger const next = expected[expectedCount - 1] + 1;

						TEST_EQ_UNSIGNED(cursor.location, next);
						TEST_EQ_UNSIGNED(cursor.length, NSRangeMax(original) - next);
					}
				}
			}
		}

		NSUInteger paged[MaximumFixtureMembers] = { 0 };
		NSUInteger pageCount = 0;
		NSRange cursor = NSRangeMake(0, QueryUpperBound);

		while (true) {
			NSUInteger page[2] = { 0, 0 };
			NSUInteger const copied = [fixture->set getIndexes:page maxCount:2 inIndexRange:&cursor];

			if (copied == 0)
				break;

			for (NSUInteger i = 0; i < copied; ++i)
				paged[pageCount++] = page[i];
		}

		TEST_EQ_UNSIGNED(pageCount, fixture->count);
		for (NSUInteger i = 0; i < fixture->count; ++i)
			TEST_EQ_UNSIGNED(paged[i], fixture->members[i]);
	}
}

static void
TestPointQueries(IndexSetFixture const *fixtures)
{
	for (NSUInteger f = 0; f < FixtureCount; ++f) {
		for (NSUInteger index = 0; index <= QueryUpperBound; ++index) {
			TEST_EQ([fixtures[f].set containsIndex:index],
				ReferenceContainsIndex(&fixtures[f], index));
			TEST_EQ_UNSIGNED([fixtures[f].set indexGreaterThanIndex:index],
				ReferenceGreater(&fixtures[f], index, false));
			TEST_EQ_UNSIGNED([fixtures[f].set indexLessThanIndex:index],
				ReferenceLess(&fixtures[f], index, false));
			TEST_EQ_UNSIGNED([fixtures[f].set indexGreaterThanOrEqualToIndex:index],
				ReferenceGreater(&fixtures[f], index, true));
			TEST_EQ_UNSIGNED([fixtures[f].set indexLessThanOrEqualToIndex:index],
				ReferenceLess(&fixtures[f], index, true));
		}
	}
}

static void
TestRangeQueries(IndexSetFixture const *fixtures)
{
	for (NSUInteger f = 0; f < FixtureCount; ++f) {
		for (NSUInteger location = 0; location <= QueryUpperBound; ++location) {
			for (NSUInteger length = 0; length <= QueryUpperBound - location; ++length) {
				NSRange const range = NSRangeMake(location, length);

				TEST_EQ([fixtures[f].set containsIndexesInRange:range],
					ReferenceContainsRange(&fixtures[f], range));
				TEST_EQ([fixtures[f].set intersectsIndexesInRange:range],
					ReferenceIntersectsRange(&fixtures[f], range));
				TEST_EQ_UNSIGNED([fixtures[f].set countOfIndexesInRange:range],
					ReferenceCountInRange(&fixtures[f], range));
			}
		}
	}
}

static void
TestIndexPredicates(IndexSetFixture const *fixtures)
{
	NSEnumerationOptions const options[] = {
		NSEnumerationNoOptions,
		NSEnumerationReverse,
		NSEnumerationConcurrent,
		(NSEnumerationOptions)(NSEnumerationConcurrent | NSEnumerationReverse)
	};
	NSRange const limits[] = {
		NSRangeMake(0, 0), NSRangeMake(0, QueryUpperBound), NSRangeMake(2, 7),
		NSRangeMake(6, 7), NSRangeMake(9, 6), NSRangeMake(QueryUpperBound, 0)
	};

	for (NSUInteger f = 0; f < FixtureCount; ++f) {
		IndexSetFixture const *fixture = &fixtures[f];
		__block bool badInitialStop = false;
		NSUInteger const firstEven = [fixture->set indexPassingTest:^bool(NSUInteger index, bool *stop) {
			if (*stop)
				badInitialStop = true;
			return (bool)(index % 2 == 0);
		}];
		NSUInteger expectedEven = NSNotFound;

		for (NSUInteger i = 0; i < fixture->count; ++i)
			if (fixture->members[i] % 2 == 0) {
				expectedEven = fixture->members[i];
				break;
			}

		TEST_EQ_UNSIGNED(firstEven, expectedEven);
		TEST(!badInitialStop);

		__block NSUInteger visits = 0;
		NSUInteger const noMatch = [fixture->set indexPassingTest:^bool(NSUInteger index, bool *stop) {
			(void)index;
			TEST(!*stop);
			++visits;
			return false;
		}];
		TEST_EQ_UNSIGNED(noMatch, NSNotFound);
		TEST_EQ_UNSIGNED(visits, fixture->count);

		visits = 0;
		NSUInteger const stopped = [fixture->set indexPassingTest:^bool(NSUInteger index, bool *stop) {
			(void)index;
			++visits;
			if (visits == 2)
				*stop = true;
			return false;
		}];
		TEST_EQ_UNSIGNED(stopped, NSNotFound);
		TEST_EQ_UNSIGNED(visits, MIN(fixture->count, (NSUInteger)2));

		for (NSUInteger o = 0; o < sizeof(options) / sizeof(options[0]); ++o) {
			bool const reverse = (options[o] & NSEnumerationReverse) != 0;
			bool const concurrent = (options[o] & NSEnumerationConcurrent) != 0;

			badInitialStop = false;
			NSUInteger const result = [fixture->set indexWithOptions:options[o]
				passingTest:^bool(NSUInteger index, bool *stop) {
					if (!concurrent && *stop)
						badInitialStop = true;
					return (bool)(index % 2 == 0);
				}];
			NSUInteger expected = NSNotFound;

			if (reverse) {
				for (NSUInteger i = fixture->count; i > 0;) {
					--i;
					if (fixture->members[i] % 2 == 0) {
						expected = fixture->members[i];
						break;
					}
				}
			} else
				expected = expectedEven;

			if (concurrent && expected != NSNotFound)
				TEST(result != NSNotFound && result % 2 == 0 &&
					ReferenceContainsIndex(fixture, result));
			else
				TEST_EQ_UNSIGNED(result, expected);
			if (!concurrent)
				TEST(!badInitialStop);
		}

		for (NSUInteger l = 0; l < sizeof(limits) / sizeof(limits[0]); ++l) {
			for (NSUInteger o = 0; o < sizeof(options) / sizeof(options[0]); ++o) {
				NSUInteger filtered[MaximumFixtureMembers];
				NSUInteger const filteredCount = ReferenceFilteredMembers(fixture, limits[l], true,
					filtered);
				bool const reverse = (options[o] & NSEnumerationReverse) != 0;
				bool const concurrent = (options[o] & NSEnumerationConcurrent) != 0;
				NSUInteger const expected = filteredCount == 0 ? NSNotFound :
					(reverse ? filtered[filteredCount - 1] : filtered[0]);
				NSUInteger const result = [fixture->set indexInRange:limits[l] options:options[o]
					passingTest:^bool(NSUInteger index, bool *stop) {
						if (!concurrent)
							TEST(!*stop);
						return (bool)(index % 2 == 0);
					}];

				if (concurrent && expected != NSNotFound)
					TEST(result != NSNotFound && result % 2 == 0 &&
						NSRangeContainsLocation(limits[l], result) &&
						ReferenceContainsIndex(fixture, result));
				else
					TEST_EQ_UNSIGNED(result, expected);
			}
		}

		if (fixture->count > 0) {
			NSUInteger const result = [fixture->set indexPassingTest:^bool(NSUInteger index, bool *stop) {
				(void)index;
				*stop = true;
				return true;
			}];
			TEST_EQ_UNSIGNED(result, fixture->members[0]);
		}
	}
}

static void
TestSetPredicates(IndexSetFixture const *fixtures)
{
	NSEnumerationOptions const options[] = {
		NSEnumerationNoOptions,
		NSEnumerationReverse,
		NSEnumerationConcurrent,
		(NSEnumerationOptions)(NSEnumerationConcurrent | NSEnumerationReverse)
	};
	NSRange const limits[] = {
		NSRangeMake(0, 0), NSRangeMake(0, QueryUpperBound), NSRangeMake(2, 7),
		NSRangeMake(6, 7), NSRangeMake(9, 6), NSRangeMake(QueryUpperBound, 0)
	};

	for (NSUInteger f = 0; f < FixtureCount; ++f) {
		IndexSetFixture const *fixture = &fixtures[f];
		NSUInteger expected[MaximumFixtureMembers];
		NSUInteger const expectedCount = ReferenceFilteredMembers(fixture,
			NSRangeMake(0, QueryUpperBound), true, expected);
		NSIndexSet *result = [fixture->set indexesPassingTest:^bool(NSUInteger index, bool *stop) {
			TEST(!*stop);
			return (bool)(index % 2 == 0);
		}];

		TestMembers(result, expected, expectedCount);

		NSIndexSet *all = [fixture->set indexesPassingTest:^bool(NSUInteger index, bool *stop) {
			(void)index;
			TEST(!*stop);
			return true;
		}];
		TestMembers(all, fixture->members, fixture->count);

		NSIndexSet *none = [fixture->set indexesPassingTest:^bool(NSUInteger index, bool *stop) {
			(void)index;
			TEST(!*stop);
			return false;
		}];
		TestMembers(none, nullptr, 0);

		for (NSUInteger o = 0; o < sizeof(options) / sizeof(options[0]); ++o) {
			bool const concurrent = (options[o] & NSEnumerationConcurrent) != 0;
			NSIndexSet *selected = [fixture->set indexesWithOptions:options[o]
				passingTest:^bool(NSUInteger index, bool *stop) {
					if (!concurrent)
						TEST(!*stop);
					return (bool)(index % 2 == 0);
				}];
			TestMembers(selected, expected, expectedCount);
		}

		for (NSUInteger l = 0; l < sizeof(limits) / sizeof(limits[0]); ++l) {
			for (NSUInteger o = 0; o < sizeof(options) / sizeof(options[0]); ++o) {
				bool const concurrent = (options[o] & NSEnumerationConcurrent) != 0;
				NSUInteger limited[MaximumFixtureMembers];
				NSUInteger const limitedCount = ReferenceFilteredMembers(fixture, limits[l], true,
					limited);
				NSIndexSet *selected = [fixture->set indexesInRange:limits[l] options:options[o]
					passingTest:^bool(NSUInteger index, bool *stop) {
						if (!concurrent)
							TEST(!*stop);
						return (bool)(index % 2 == 0);
					}];

				TestMembers(selected, limited, limitedCount);
			}
		}

		__block NSUInteger visits = 0;
		NSIndexSet *stopped = [fixture->set indexesPassingTest:^bool(NSUInteger index, bool *stop) {
			(void)index;
			++visits;
			if (visits == 2)
				*stop = true;
			return true;
		}];
		NSUInteger const stoppedCount = MIN(fixture->count, (NSUInteger)2);
		TestMembers(stopped, fixture->members, stoppedCount);
		TEST_EQ_UNSIGNED(visits, stoppedCount);

		visits = 0;
		NSIndexSet *reverseStopped = [fixture->set indexesWithOptions:NSEnumerationReverse
			passingTest:^bool(NSUInteger index, bool *stop) {
				(void)index;
				++visits;
				if (visits == 2)
					*stop = true;
				return true;
			}];
		NSUInteger reverseExpected[2];
		for (NSUInteger i = 0; i < stoppedCount; ++i)
			reverseExpected[stoppedCount - i - 1] = fixture->members[fixture->count - i - 1];
		TestMembers(reverseStopped, reverseExpected, stoppedCount);
		TEST_EQ_UNSIGNED(visits, stoppedCount);
	}
}

static void
TestEnumerateIndexes(IndexSetFixture const *fixtures)
{
	NSRange const limits[] = {
		NSRangeMake(0, 0), NSRangeMake(0, QueryUpperBound), NSRangeMake(2, 7),
		NSRangeMake(6, 7), NSRangeMake(9, 6), NSRangeMake(QueryUpperBound, 0)
	};

	for (NSUInteger f = 0; f < FixtureCount; ++f) {
		IndexSetFixture const *fixture = &fixtures[f];
		NSUInteger visited[MaximumFixtureMembers] = { 0 };
		NSUInteger *const visitedIndexes = visited;
		__block NSUInteger visitCount = 0;
		__block bool badInitialStop = false;

		[fixture->set enumerateIndexesUsingBlock:^(NSUInteger index, bool *stop) {
			if (*stop)
				badInitialStop = true;
			visitedIndexes[visitCount++] = index;
		}];
		TEST(!badInitialStop);
		TEST_EQ_UNSIGNED(visitCount, fixture->count);
		for (NSUInteger i = 0; i < fixture->count; ++i)
			TEST_EQ_UNSIGNED(visited[i], fixture->members[i]);

		memset(visited, 0, sizeof(visited));
		visitCount = 0;
		[fixture->set enumerateIndexesWithOptions:NSEnumerationNoOptions
			usingBlock:^(NSUInteger index, bool *stop) {
				TEST(!*stop);
				visitedIndexes[visitCount++] = index;
			}];
		TEST_EQ_UNSIGNED(visitCount, fixture->count);
		for (NSUInteger i = 0; i < fixture->count; ++i)
			TEST_EQ_UNSIGNED(visited[i], fixture->members[i]);

		memset(visited, 0, sizeof(visited));
		visitCount = 0;
		[fixture->set enumerateIndexesWithOptions:NSEnumerationReverse
			usingBlock:^(NSUInteger index, bool *stop) {
				TEST(!*stop);
				visitedIndexes[visitCount++] = index;
			}];
		TEST_EQ_UNSIGNED(visitCount, fixture->count);
		for (NSUInteger i = 0; i < fixture->count; ++i)
			TEST_EQ_UNSIGNED(visited[i], fixture->members[fixture->count - i - 1]);

		for (NSUInteger reverse = 0; reverse < 2; ++reverse) {
			_Atomic NSUInteger hits[QueryUpperBound + 1] = { 0 };
			_Atomic NSUInteger *const hitCounts = hits;
			_Atomic bool badStop = false;
			_Atomic bool *const badStopFlag = &badStop;
			NSEnumerationOptions const options = (NSEnumerationOptions)(NSEnumerationConcurrent |
				(reverse != 0 ? NSEnumerationReverse : NSEnumerationNoOptions));

			[fixture->set enumerateIndexesWithOptions:options
				usingBlock:^(NSUInteger index, bool *stop) {
					if (*stop)
						atomic_store_explicit(badStopFlag, true, memory_order_relaxed);
					atomic_fetch_add_explicit(&hitCounts[index], 1, memory_order_relaxed);
				}];

			TEST(!atomic_load_explicit(&badStop, memory_order_relaxed));
			for (NSUInteger index = 0; index <= QueryUpperBound; ++index)
				TEST_EQ_UNSIGNED(atomic_load_explicit(&hits[index], memory_order_relaxed),
					ReferenceContainsIndex(fixture, index) ? 1 : 0);
		}

		for (NSUInteger l = 0; l < sizeof(limits) / sizeof(limits[0]); ++l) {
			for (NSUInteger reverse = 0; reverse < 2; ++reverse) {
				NSUInteger expected[MaximumFixtureMembers];
				NSUInteger const expectedCount = ReferenceFilteredMembers(fixture, limits[l], false,
					expected);
				NSEnumerationOptions const options = reverse != 0 ? NSEnumerationReverse :
					NSEnumerationNoOptions;

				memset(visited, 0, sizeof(visited));
				visitCount = 0;
				[fixture->set enumerateIndexesInRange:limits[l] options:options
					usingBlock:^(NSUInteger index, bool *stop) {
						TEST(!*stop);
						visitedIndexes[visitCount++] = index;
					}];
				TEST_EQ_UNSIGNED(visitCount, expectedCount);
				for (NSUInteger i = 0; i < expectedCount; ++i)
					TEST_EQ_UNSIGNED(visited[i], reverse != 0 ? expected[expectedCount - i - 1] :
						expected[i]);
			}

			for (NSUInteger reverse = 0; reverse < 2; ++reverse) {
				_Atomic NSUInteger hits[QueryUpperBound + 1] = { 0 };
				_Atomic NSUInteger *const hitCounts = hits;
				_Atomic bool badStop = false;
				_Atomic bool *const badStopFlag = &badStop;
				NSEnumerationOptions const options = (NSEnumerationOptions)(NSEnumerationConcurrent |
					(reverse != 0 ? NSEnumerationReverse : NSEnumerationNoOptions));

				[fixture->set enumerateIndexesInRange:limits[l] options:options
					usingBlock:^(NSUInteger index, bool *stop) {
						if (*stop)
							atomic_store_explicit(badStopFlag, true, memory_order_relaxed);
						atomic_fetch_add_explicit(&hitCounts[index], 1, memory_order_relaxed);
					}];
				TEST(!atomic_load_explicit(&badStop, memory_order_relaxed));
				for (NSUInteger index = 0; index <= QueryUpperBound; ++index) {
					bool const expected = ReferenceContainsIndex(fixture, index) &&
						NSRangeContainsLocation(limits[l], index);
					TEST_EQ_UNSIGNED(atomic_load_explicit(&hits[index], memory_order_relaxed),
						expected ? 1 : 0);
				}
			}
		}

		memset(visited, 0, sizeof(visited));
		visitCount = 0;
		[fixture->set enumerateIndexesUsingBlock:^(NSUInteger index, bool *stop) {
			visitedIndexes[visitCount++] = index;
			if (visitCount == 2)
				*stop = true;
		}];
		TEST_EQ_UNSIGNED(visitCount, MIN(fixture->count, (NSUInteger)2));
		for (NSUInteger i = 0; i < visitCount; ++i)
			TEST_EQ_UNSIGNED(visited[i], fixture->members[i]);
	}
}

static void
TestEnumerateRanges(IndexSetFixture const *fixtures)
{
	NSRange const limits[] = {
		NSRangeMake(0, 0), NSRangeMake(0, QueryUpperBound), NSRangeMake(2, 7),
		NSRangeMake(6, 7), NSRangeMake(9, 6), NSRangeMake(QueryUpperBound, 0)
	};

	for (NSUInteger f = 0; f < FixtureCount; ++f) {
		IndexSetFixture const *fixture = &fixtures[f];
		NSRange expected[MaximumFixtureMembers];
		NSUInteger const expectedCount = ReferenceRanges(fixture,
			NSRangeMake(0, QueryUpperBound), expected);
		NSRange visited[MaximumFixtureMembers] = { NSRangeZero };
		NSRange *const visitedRanges = visited;
		__block NSUInteger visitCount = 0;

		[fixture->set enumerateRangesUsingBlock:^(NSRange range, bool *stop) {
			TEST(!*stop);
			visitedRanges[visitCount++] = range;
		}];
		TEST_EQ_UNSIGNED(visitCount, expectedCount);
		for (NSUInteger i = 0; i < expectedCount; ++i)
			TEST(NSRangeEqualToRange(visited[i], expected[i]));

		memset(visited, 0, sizeof(visited));
		visitCount = 0;
		[fixture->set enumerateRangesWithOptions:NSEnumerationNoOptions
			usingBlock:^(NSRange range, bool *stop) {
				TEST(!*stop);
				visitedRanges[visitCount++] = range;
			}];
		TEST_EQ_UNSIGNED(visitCount, expectedCount);
		for (NSUInteger i = 0; i < expectedCount; ++i)
			TEST(NSRangeEqualToRange(visited[i], expected[i]));

		memset(visited, 0, sizeof(visited));
		visitCount = 0;
		[fixture->set enumerateRangesWithOptions:NSEnumerationReverse
			usingBlock:^(NSRange range, bool *stop) {
				TEST(!*stop);
				visitedRanges[visitCount++] = range;
			}];
		TEST_EQ_UNSIGNED(visitCount, expectedCount);
		for (NSUInteger i = 0; i < expectedCount; ++i)
			TEST(NSRangeEqualToRange(visited[i], expected[expectedCount - i - 1]));

		NSRange const *const expectedRanges = expected;
		for (NSUInteger reverse = 0; reverse < 2; ++reverse) {
			_Atomic NSUInteger hits[MaximumFixtureMembers] = { 0 };
			_Atomic NSUInteger *const hitCounts = hits;
			_Atomic bool unmatched = false;
			_Atomic bool *const unmatchedFlag = &unmatched;
			_Atomic bool badStop = false;
			_Atomic bool *const badStopFlag = &badStop;
			NSEnumerationOptions const options = (NSEnumerationOptions)(NSEnumerationConcurrent |
				(reverse != 0 ? NSEnumerationReverse : NSEnumerationNoOptions));

			[fixture->set enumerateRangesWithOptions:options
				usingBlock:^(NSRange range, bool *stop) {
					bool matched = false;

					if (*stop)
						atomic_store_explicit(badStopFlag, true, memory_order_relaxed);
					for (NSUInteger i = 0; i < expectedCount; ++i)
						if (NSRangeEqualToRange(range, expectedRanges[i])) {
							atomic_fetch_add_explicit(&hitCounts[i], 1, memory_order_relaxed);
							matched = true;
							break;
						}
					if (!matched)
						atomic_store_explicit(unmatchedFlag, true, memory_order_relaxed);
				}];
			TEST(!atomic_load_explicit(&badStop, memory_order_relaxed));
			TEST(!atomic_load_explicit(&unmatched, memory_order_relaxed));
			for (NSUInteger i = 0; i < expectedCount; ++i)
				TEST_EQ_UNSIGNED(atomic_load_explicit(&hits[i], memory_order_relaxed), 1);
		}

		for (NSUInteger l = 0; l < sizeof(limits) / sizeof(limits[0]); ++l) {
			NSRange limited[MaximumFixtureMembers];
			NSUInteger const limitedCount = ReferenceRanges(fixture, limits[l], limited);
			NSRange const *const limitedRanges = limited;

			for (NSUInteger reverse = 0; reverse < 2; ++reverse) {
				NSEnumerationOptions const options = reverse != 0 ? NSEnumerationReverse :
					NSEnumerationNoOptions;

				memset(visited, 0, sizeof(visited));
				visitCount = 0;
				[fixture->set enumerateRangesInRange:limits[l] options:options
					usingBlock:^(NSRange range, bool *stop) {
						TEST(!*stop);
						visitedRanges[visitCount++] = range;
					}];
				TEST_EQ_UNSIGNED(visitCount, limitedCount);
				for (NSUInteger i = 0; i < limitedCount; ++i)
					TEST(NSRangeEqualToRange(visited[i], reverse != 0 ?
						limited[limitedCount - i - 1] : limited[i]));
			}

			for (NSUInteger reverse = 0; reverse < 2; ++reverse) {
				_Atomic NSUInteger hits[MaximumFixtureMembers] = { 0 };
				_Atomic NSUInteger *const hitCounts = hits;
				_Atomic bool unmatched = false;
				_Atomic bool *const unmatchedFlag = &unmatched;
				_Atomic bool badStop = false;
				_Atomic bool *const badStopFlag = &badStop;
				NSEnumerationOptions const options = (NSEnumerationOptions)(NSEnumerationConcurrent |
					(reverse != 0 ? NSEnumerationReverse : NSEnumerationNoOptions));

				[fixture->set enumerateRangesInRange:limits[l] options:options
					usingBlock:^(NSRange range, bool *stop) {
						bool matched = false;

						if (*stop)
							atomic_store_explicit(badStopFlag, true, memory_order_relaxed);
						for (NSUInteger i = 0; i < limitedCount; ++i)
							if (NSRangeEqualToRange(range, limitedRanges[i])) {
								atomic_fetch_add_explicit(&hitCounts[i], 1, memory_order_relaxed);
								matched = true;
								break;
							}
						if (!matched)
							atomic_store_explicit(unmatchedFlag, true, memory_order_relaxed);
					}];
				TEST(!atomic_load_explicit(&badStop, memory_order_relaxed));
				TEST(!atomic_load_explicit(&unmatched, memory_order_relaxed));
				for (NSUInteger i = 0; i < limitedCount; ++i)
					TEST_EQ_UNSIGNED(atomic_load_explicit(&hits[i], memory_order_relaxed), 1);
			}
		}

		memset(visited, 0, sizeof(visited));
		visitCount = 0;
		[fixture->set enumerateRangesUsingBlock:^(NSRange range, bool *stop) {
			visitedRanges[visitCount++] = range;
			if (visitCount == 2)
				*stop = true;
		}];
		TEST_EQ_UNSIGNED(visitCount, MIN(expectedCount, (NSUInteger)2));
		for (NSUInteger i = 0; i < visitCount; ++i)
			TEST(NSRangeEqualToRange(visited[i], expected[i]));
	}
}

static void
TestBoundaryIndexes(void)
{
	@autoreleasepool {
		NSUInteger const maximumIndex = NSNotFound - 1;
		NSMutableIndexSet *builder = [NSMutableIndexSet indexSet];

		[builder addIndex:0];
		[builder addIndex:2];
		[builder addIndexesInRange:NSRangeMake(maximumIndex - 2, 3)];

		NSIndexSet *zero = [NSIndexSet indexSet];
		NSIndexSet *single = [NSIndexSet indexSetWithIndex:maximumIndex];
		NSIndexSet *range = [NSIndexSet indexSetWithIndexesInRange:
			NSRangeMake(maximumIndex - 2, 3)];
		NSIndexSet *many = [builder copy];
		NSUInteger const singleMembers[] = { maximumIndex };
		NSUInteger const rangeMembers[] = { maximumIndex - 2, maximumIndex - 1, maximumIndex };
		NSUInteger const manyMembers[] = { 0, 2, maximumIndex - 2, maximumIndex - 1, maximumIndex };
		IndexSetFixture const fixtures[] = {
			{ zero, "NSZeroIndexSet", nullptr, 0 },
			{ single, "NSSingleEntryIndexSet", singleMembers, 1 },
			{ range, "NSSingleRangeIndexSet", rangeMembers, 3 },
			{ many, "NSInlineIndexSet", manyMembers, 5 }
		};
		NSUInteger const queries[] = {
			0, 1, 2, 3, maximumIndex - 3, maximumIndex - 2, maximumIndex - 1, maximumIndex
		};
		NSRange const ranges[] = {
			NSRangeMake(NSNotFound, 0), NSRangeMake(maximumIndex, 1),
			NSRangeMake(maximumIndex - 2, 3), NSRangeMake(0, NSNotFound)
		};

		for (NSUInteger f = 0; f < FixtureCount; ++f) {
			for (NSUInteger q = 0; q < sizeof(queries) / sizeof(queries[0]); ++q) {
				NSUInteger const index = queries[q];

				TEST_EQ([fixtures[f].set containsIndex:index],
					ReferenceContainsIndex(&fixtures[f], index));
				TEST_EQ_UNSIGNED([fixtures[f].set indexGreaterThanIndex:index],
					ReferenceGreater(&fixtures[f], index, false));
				TEST_EQ_UNSIGNED([fixtures[f].set indexLessThanIndex:index],
					ReferenceLess(&fixtures[f], index, false));
				TEST_EQ_UNSIGNED([fixtures[f].set indexGreaterThanOrEqualToIndex:index],
					ReferenceGreater(&fixtures[f], index, true));
				TEST_EQ_UNSIGNED([fixtures[f].set indexLessThanOrEqualToIndex:index],
					ReferenceLess(&fixtures[f], index, true));
			}

			for (NSUInteger r = 0; r < sizeof(ranges) / sizeof(ranges[0]); ++r) {
				TEST_EQ([fixtures[f].set containsIndexesInRange:ranges[r]],
					ReferenceContainsRange(&fixtures[f], ranges[r]));
				TEST_EQ([fixtures[f].set intersectsIndexesInRange:ranges[r]],
					ReferenceIntersectsRange(&fixtures[f], ranges[r]));
				TEST_EQ_UNSIGNED([fixtures[f].set countOfIndexesInRange:ranges[r]],
					ReferenceCountInRange(&fixtures[f], ranges[r]));
			}

			NSUInteger buffer[MaximumFixtureMembers] = { 0 };
			NSRange cursor = NSRangeMake(0, NSNotFound);
			NSUInteger const copied = [fixtures[f].set getIndexes:buffer
				maxCount:MaximumFixtureMembers inIndexRange:&cursor];
			TEST_EQ_UNSIGNED(copied, fixtures[f].count);
			for (NSUInteger i = 0; i < copied; ++i)
				TEST_EQ_UNSIGNED(buffer[i], fixtures[f].members[i]);
		}
	}
}

static void
TestEveryRepresentation(void)
{
	@autoreleasepool {
		NSIndexSet *zero = [NSIndexSet indexSet];
		NSIndexSet *single = [NSIndexSet indexSetWithIndex:7];
		NSIndexSet *range = [NSIndexSet indexSetWithIndexesInRange:NSRangeMake(5, 5)];
		NSIndexSet *many = ManyIndexSet();
		NSUInteger const singleMembers[] = { 7 };
		NSUInteger const rangeMembers[] = { 5, 6, 7, 8, 9 };
		NSUInteger const manyMembers[] = { 1, 2, 7, 8, 12, 13, 14 };
		IndexSetFixture const fixtures[] = {
			{ zero, "NSZeroIndexSet", nullptr, 0 },
			{ single, "NSSingleEntryIndexSet", singleMembers, 1 },
			{ range, "NSSingleRangeIndexSet", rangeMembers, 5 },
			{ many, "NSInlineIndexSet", manyMembers, 7 }
		};

		TestPropertiesAndIdentity(fixtures);
		TestPairwiseSetMethods(fixtures);
		TestAdditionalContainmentCases(fixtures);
		TestGetIndexes(fixtures);
		TestPointQueries(fixtures);
		TestRangeQueries(fixtures);
		TestIndexPredicates(fixtures);
		TestSetPredicates(fixtures);
		TestEnumerateIndexes(fixtures);
		TestEnumerateRanges(fixtures);
	}
}

int
main(void)
{
	TestEveryRepresentation();
	TestBoundaryIndexes();

	return TestFinish();
}

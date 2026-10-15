#import <Foundation/NSIndexSet.h>
#import "Test.h"

#import <objc/runtime.h>

#include <stdint.h>

static void
TestMembers(NSIndexSet *set, NSUInteger const *expected, NSUInteger expectedCount)
{
	NSUInteger actual[512];
	NSUInteger const copied = [set getIndexes:actual maxCount:512 inIndexRange:nullptr];

	TEST_EQ_UNSIGNED(set.count, expectedCount);
	TEST_EQ_UNSIGNED(copied, expectedCount);

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

static NSMutableIndexSet *
SetWithRanges(NSRange const *ranges, NSUInteger rangeCount)
{
	NSMutableIndexSet *set = [NSMutableIndexSet indexSet];

	for (NSUInteger i = 0; i < rangeCount; ++i)
		[set addIndexesInRange:ranges[i]];

	return set;
}

static void
TestConstructionAndCopies(void)
{
	@autoreleasepool {
		NSMutableIndexSet *empty = [NSMutableIndexSet indexSet];
		NSMutableIndexSet *single = [[NSMutableIndexSet alloc] initWithIndex:7];
		NSMutableIndexSet *range = [[NSMutableIndexSet alloc]
						initWithIndexesInRange:NSRangeMake(10, 4)];
		NSMutableIndexSet *many = SetWithRanges((NSRange[]){ NSRangeMake(1, 2), NSRangeMake(8, 3) }, 2);
		NSIndexSet *emptyCopy = [empty copy];
		NSIndexSet *singleCopy = [single copy];
		NSIndexSet *rangeCopy = [range copy];
		NSIndexSet *manyCopy = [many copy];
		NSMutableIndexSet *mutableCopy = [many mutableCopy];

		TEST_STR_EQ(object_getClassName(empty), "NSMutableInlineIndexSet");
		TEST_STR_EQ(object_getClassName(single), "NSMutableInlineIndexSet");
		TEST_STR_EQ(object_getClassName(range), "NSMutableInlineIndexSet");
		TEST_STR_EQ(object_getClassName(many), "NSMutableInlineIndexSet");
		TEST_STR_EQ(object_getClassName(emptyCopy), "NSZeroIndexSet");
		TEST_STR_EQ(object_getClassName(singleCopy), "NSSingleEntryIndexSet");
		TEST_STR_EQ(object_getClassName(rangeCopy), "NSSingleRangeIndexSet");
		TEST_STR_EQ(object_getClassName(manyCopy), "NSInlineIndexSet");
		TEST_STR_EQ(object_getClassName(mutableCopy), "NSMutableInlineIndexSet");

		TEST([many isEqualToIndexSet:manyCopy]);
		TEST([manyCopy isEqualToIndexSet:many]);
		TEST([many isEqualToIndexSet:mutableCopy]);
		TEST_EQ_UNSIGNED(many.hash, manyCopy.hash);
		TEST_EQ_UNSIGNED(many.hash, mutableCopy.hash);

		[many addIndex:100];
		[mutableCopy addIndex:200];
		TEST([manyCopy containsIndex:100] == false);
		TEST([many containsIndex:200] == false);
		TEST([mutableCopy containsIndex:100] == false);

		[empty addIndex:3];
		TEST_EQ_UNSIGNED(empty.count, 1);
		TEST_EQ_UNSIGNED(emptyCopy.count, 0);
	}
}

static void
TestRangeEdits(void)
{
	@autoreleasepool {
		NSMutableIndexSet *set = [NSMutableIndexSet indexSet];

		[set addIndex:4];
		[set addIndex:6];
		[set addIndex:5];
		TestMembers(set, (NSUInteger[]){ 4, 5, 6 }, 3);

		[set removeIndex:5];
		TestMembers(set, (NSUInteger[]){ 4, 6 }, 2);

		[set addIndexesInRange:NSRangeMake(2, 7)];
		[set addIndexesInRange:NSRangeMake(4, 2)];
		TestMembers(set, (NSUInteger[]){ 2, 3, 4, 5, 6, 7, 8 }, 7);

		[set removeIndexesInRange:NSRangeMake(4, 2)];
		TestMembers(set, (NSUInteger[]){ 2, 3, 6, 7, 8 }, 5);

		[set addIndexes:SetWithRanges((NSRange[]){ NSRangeMake(0, 2), NSRangeMake(9, 2) }, 2)];
		TestMembers(set, (NSUInteger[]){ 0, 1, 2, 3, 6, 7, 8, 9, 10 }, 9);

		[set removeIndexes:SetWithRanges((NSRange[]){ NSRangeMake(1, 2), NSRangeMake(7, 3) }, 2)];
		TestMembers(set, (NSUInteger[]){ 0, 3, 6, 10 }, 4);

		[set removeIndexes:set];
		TestMembers(set, nullptr, 0);
	}
}

[[clang::no_sanitize("integer")]]
static uint32_t
NextRandom(uint32_t *state)
{
	*state = *state * UINT32_C(1664525) + UINT32_C(1013904223);
	return *state;
}

static void
TestDeterministicEditSweep(void)
{
	@autoreleasepool {
		NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
		bool expected[256] = { false };
		uint32_t state = UINT32_C(0x13579bdf);

		for (NSUInteger operation = 0; operation < 1000; ++operation) {
			NSUInteger const kind = NextRandom(&state) % 4;
			NSUInteger const location = NextRandom(&state) % 256;
			NSUInteger length = NextRandom(&state) % 17;

			if (length > 256 - location)
				length = 256 - location;

			if (kind == 0) {
				[set addIndex:location];
				expected[location] = true;
			} else if (kind == 1) {
				[set removeIndex:location];
				expected[location] = false;
			} else if (kind == 2) {
				[set addIndexesInRange:NSRangeMake(location, length)];
				for (NSUInteger i = location; i < location + length; ++i)
					expected[i] = true;
			} else {
				[set removeIndexesInRange:NSRangeMake(location, length)];
				for (NSUInteger i = location; i < location + length; ++i)
					expected[i] = false;
			}

			if (operation % 25 == 0 || operation == 999) {
				NSUInteger members[256];
				NSUInteger memberCount = 0;

				for (NSUInteger i = 0; i < 256; ++i)
					if (expected[i])
						members[memberCount++] = i;

				TestMembers(set, members, memberCount);

				NSIndexSet *snapshot = [set copy];
				TEST([set isEqualToIndexSet:snapshot]);
				TEST([snapshot isEqualToIndexSet:set]);
				TEST_EQ_UNSIGNED(set.hash, snapshot.hash);
			}
		}
	}
}

static void
TestQueries(void)
{
	@autoreleasepool {
		NSMutableIndexSet *set = SetWithRanges((NSRange[]){ NSRangeMake(2, 3), NSRangeMake(10, 2) }, 2);
		NSUInteger buffer[4] = { 0 };
		NSRange cursor = NSRangeMake(3, 8);
		NSUInteger copied;
		NSUInteger visited[5] = { 0 };
		NSUInteger *const visitedIndexes = visited;
		__block NSUInteger visitCount = 0;
		NSRange visitedRanges[2] = { NSRangeZero, NSRangeZero };
		NSRange *const visitedRangeBuffer = visitedRanges;
		__block NSUInteger rangeCount = 0;

		copied = [set getIndexes:buffer maxCount:4 inIndexRange:&cursor];
		TEST_EQ_UNSIGNED(copied, 3);
		TEST_EQ_UNSIGNED(buffer[0], 3);
		TEST_EQ_UNSIGNED(buffer[1], 4);
		TEST_EQ_UNSIGNED(buffer[2], 10);
		TEST_EQ_UNSIGNED(cursor.location, 11);
		TEST_EQ_UNSIGNED(cursor.length, 0);

		TEST([set containsIndexesInRange:NSRangeMake(2, 3)]);
		TEST([set containsIndexesInRange:NSRangeMake(3, 3)] == false);
		TEST([set intersectsIndexesInRange:NSRangeMake(5, 5)] == false);
		TEST([set intersectsIndexesInRange:NSRangeMake(5, 6)]);
		TEST_EQ_UNSIGNED([set countOfIndexesInRange:NSRangeMake(3, 8)], 3);
		TEST_EQ_UNSIGNED([set indexPassingTest:^(NSUInteger index, bool *stop) {
			(void)stop;
			return (bool)(index == 4);
		}], 4);
		TEST_EQ_UNSIGNED([set indexWithOptions:NSEnumerationReverse
			passingTest:^(NSUInteger index, bool *stop) {
				(void)stop;
				return (bool)(index < 11);
			}], 10);
		TEST_EQ_UNSIGNED([set indexInRange:NSRangeMake(5, 6) options:NSEnumerationNoOptions
			passingTest:^(NSUInteger index, bool *stop) {
				(void)index;
				(void)stop;
				return true;
			}], 10);

		NSIndexSet *odds = [set indexesPassingTest:^(NSUInteger index, bool *stop) {
			(void)stop;
			return (bool)(index % 2 != 0);
		}];
		TestMembers(odds, (NSUInteger[]){ 3, 11 }, 2);

		[set enumerateIndexesWithOptions:NSEnumerationReverse
			usingBlock:^(NSUInteger index, bool *stop) {
				(void)stop;
				visitedIndexes[visitCount++] = index;
			}];
		TEST_EQ_UNSIGNED(visitCount, 5);
		TEST_EQ_UNSIGNED(visited[0], 11);
		TEST_EQ_UNSIGNED(visited[1], 10);
		TEST_EQ_UNSIGNED(visited[2], 4);
		TEST_EQ_UNSIGNED(visited[3], 3);
		TEST_EQ_UNSIGNED(visited[4], 2);

		[set enumerateRangesInRange:NSRangeMake(3, 8) options:NSEnumerationNoOptions
			usingBlock:^(NSRange range, bool *stop) {
				(void)stop;
				visitedRangeBuffer[rangeCount++] = range;
			}];
		TEST_EQ_UNSIGNED(rangeCount, 2);
		TEST_EQ_UNSIGNED(visitedRanges[0].location, 3);
		TEST_EQ_UNSIGNED(visitedRanges[0].length, 2);
		TEST_EQ_UNSIGNED(visitedRanges[1].location, 10);
		TEST_EQ_UNSIGNED(visitedRanges[1].length, 1);

		NSMutableIndexSet *empty = [NSMutableIndexSet indexSet];
		__block bool invoked = false;
		NSIndexSet *filteredEmpty = [empty indexesPassingTest:^(NSUInteger index, bool *stop) {
			(void)index;
			(void)stop;
			invoked = true;
			return true;
		}];
		TEST(invoked == false);
		TEST_STR_EQ(object_getClassName(filteredEmpty), "NSZeroIndexSet");
	}
}

static void
TestShiftsAndBoundaries(void)
{
	@autoreleasepool {
		NSMutableIndexSet *set = [[NSMutableIndexSet alloc]
			initWithIndexesInRange:NSRangeMake(0, 3)];

		[set shiftIndexesStartingAtIndex:1 by:2];
		TestMembers(set, (NSUInteger[]){ 0, 3, 4 }, 3);

		[set shiftIndexesStartingAtIndex:3 by:-2];
		TestMembers(set, (NSUInteger[]){ 0, 1, 2 }, 3);

		[set shiftIndexesStartingAtIndex:1 by:NSIntegerMin];
		TestMembers(set, nullptr, 0);
	}
}

int
main(void)
{
	TestConstructionAndCopies();
	TestRangeEdits();
	TestDeterministicEditSweep();
	TestQueries();
	TestShiftsAndBoundaries();

	return TestFinish();
}

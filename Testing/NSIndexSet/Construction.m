#import <Foundation/NSIndexSet.h>
#import "Test.h"

#import <objc/runtime.h>

static void
TestMembers(NSIndexSet *set, NSUInteger const *expected, NSUInteger expectedCount)
{
	NSUInteger actual[16] = { 0 };
	NSUInteger const copied = [set getIndexes:actual maxCount:16 inIndexRange:nullptr];

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

static void
TestObject(NSIndexSet *set, char const *className, NSUInteger const *expected,
	NSUInteger expectedCount)
{
	TEST(set != nil);
	TEST_STR_EQ(object_getClassName(set), className);
	TestMembers(set, expected, expectedCount);
}

static NSIndexSet *
ManyIndexSet(void)
{
	NSMutableIndexSet *builder = [NSMutableIndexSet indexSet];

	[builder addIndexesInRange:NSRangeMake(1, 2)];
	[builder addIndexesInRange:NSRangeMake(7, 2)];
	[builder addIndexesInRange:NSRangeMake(12, 3)];

	return [builder copy];
}

static NSMutableIndexSet *
MutableManyIndexSet(void)
{
	NSMutableIndexSet *set = [NSMutableIndexSet indexSet];

	[set addIndexesInRange:NSRangeMake(1, 2)];
	[set addIndexesInRange:NSRangeMake(7, 2)];
	[set addIndexesInRange:NSRangeMake(12, 3)];

	return set;
}

static void
TestEmptyConstruction(void)
{
	@autoreleasepool {
		NSIndexSet *set = [NSIndexSet indexSet];

		TestObject(set, "NSZeroIndexSet", nullptr, 0);
		TEST(set == [NSIndexSet indexSet]);
	}

	@autoreleasepool {
		NSIndexSet *set = [[NSIndexSet alloc] init];

		TestObject(set, "NSZeroIndexSet", nullptr, 0);
		TEST(set == [NSIndexSet indexSet]);
	}

	@autoreleasepool {
		NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:NSRangeMake(0, 0)];

		TestObject(set, "NSZeroIndexSet", nullptr, 0);
		TEST(set == [NSIndexSet indexSet]);
	}

	@autoreleasepool {
		NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:NSRangeMake(47, 0)];

		TestObject(set, "NSZeroIndexSet", nullptr, 0);
		TEST(set == [NSIndexSet indexSet]);
	}

	@autoreleasepool {
		NSIndexSet *set = [[NSIndexSet alloc]
			initWithIndexesInRange:NSRangeMake(NSNotFound, 0)];

		TestObject(set, "NSZeroIndexSet", nullptr, 0);
		TEST(set == [NSIndexSet indexSet]);
	}
}

static void
TestSingleEntryConstruction(void)
{
	@autoreleasepool {
		NSUInteger const expected[] = { 0 };
		NSIndexSet *set = [NSIndexSet indexSetWithIndex:0];

		TestObject(set, "NSSingleEntryIndexSet", expected, 1);
	}

	@autoreleasepool {
		NSUInteger const expected[] = { 17 };
		NSIndexSet *set = [[NSIndexSet alloc] initWithIndex:17];

		TestObject(set, "NSSingleEntryIndexSet", expected, 1);
	}

	@autoreleasepool {
		NSUInteger const expected[] = { 29 };
		NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:NSRangeMake(29, 1)];

		TestObject(set, "NSSingleEntryIndexSet", expected, 1);
	}

	@autoreleasepool {
		NSUInteger const expected[] = { NSNotFound - 1 };
		NSIndexSet *set = [[NSIndexSet alloc] initWithIndex:NSNotFound - 1];

		TestObject(set, "NSSingleEntryIndexSet", expected, 1);
	}

	@autoreleasepool {
		NSUInteger const expected[] = { NSNotFound - 1 };
		NSIndexSet *set = [[NSIndexSet alloc]
			initWithIndexesInRange:NSRangeMake(NSNotFound - 1, 1)];

		TestObject(set, "NSSingleEntryIndexSet", expected, 1);
	}
}

static void
TestSingleRangeConstruction(void)
{
	@autoreleasepool {
		NSUInteger const expected[] = { 0, 1 };
		NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:NSRangeMake(0, 2)];

		TestObject(set, "NSSingleRangeIndexSet", expected, 2);
	}

	@autoreleasepool {
		NSUInteger const expected[] = { 5, 6, 7, 8, 9 };
		NSIndexSet *set = [[NSIndexSet alloc] initWithIndexesInRange:NSRangeMake(5, 5)];

		TestObject(set, "NSSingleRangeIndexSet", expected, 5);
	}

	@autoreleasepool {
		NSUInteger const expected[] = { NSNotFound - 3, NSNotFound - 2, NSNotFound - 1 };
		NSIndexSet *set = [[NSIndexSet alloc]
			initWithIndexesInRange:NSRangeMake(NSNotFound - 3, 3)];

		TestObject(set, "NSSingleRangeIndexSet", expected, 3);
	}
}

static void
TestManyRangeConstruction(void)
{
	@autoreleasepool {
		NSUInteger const expected[] = { 1, 2, 7, 8, 12, 13, 14 };
		NSIndexSet *set = ManyIndexSet();

		TestObject(set, "NSInlineIndexSet", expected, 7);
	}

	@autoreleasepool {
		NSUInteger const expected[] = { 0, 2, NSNotFound - 3, NSNotFound - 2, NSNotFound - 1 };
		NSMutableIndexSet *builder = [NSMutableIndexSet indexSet];

		[builder addIndex:0];
		[builder addIndex:2];
		[builder addIndexesInRange:NSRangeMake(NSNotFound - 3, 3)];

		NSIndexSet *set = [builder copy];
		TestObject(set, "NSInlineIndexSet", expected, 5);
	}
}

static void
TestInitWithImmutableIndexSet(void)
{
	@autoreleasepool {
		NSIndexSet *sources[] = {
			[NSIndexSet indexSet],
			[NSIndexSet indexSetWithIndex:7],
			[NSIndexSet indexSetWithIndexesInRange:NSRangeMake(5, 5)],
			ManyIndexSet()
		};
		char const *const classNames[] = {
			"NSZeroIndexSet", "NSSingleEntryIndexSet", "NSSingleRangeIndexSet", "NSInlineIndexSet"
		};

		for (NSUInteger i = 0; i < 4; ++i) {
			NSIndexSet *set = [[NSIndexSet alloc] initWithIndexSet:sources[i]];

			TEST(set == sources[i]);
			TEST_STR_EQ(object_getClassName(set), classNames[i]);
			TEST([set isEqualToIndexSet:sources[i]]);
		}
	}
}

static void
TestInitWithMutableIndexSet(void)
{
	@autoreleasepool {
		NSMutableIndexSet *sources[] = {
			[NSMutableIndexSet indexSet],
			[[NSMutableIndexSet alloc] initWithIndex:7],
			[[NSMutableIndexSet alloc] initWithIndexesInRange:NSRangeMake(5, 5)],
			MutableManyIndexSet()
		};
		char const *const classNames[] = {
			"NSZeroIndexSet", "NSSingleEntryIndexSet", "NSSingleRangeIndexSet", "NSInlineIndexSet"
		};

		for (NSUInteger i = 0; i < 4; ++i) {
			NSIndexSet *set = [[NSIndexSet alloc] initWithIndexSet:sources[i]];
			NSUInteger const oldCount = set.count;

			TEST((id)set != (id)sources[i]);
			TEST_STR_EQ(object_getClassName(set), classNames[i]);
			TEST([set isEqualToIndexSet:sources[i]]);
			[sources[i] addIndex:40 + i];
			TEST_EQ_UNSIGNED(set.count, oldCount);
			TEST(![set containsIndex:40 + i]);
		}
	}
}

static void
TestCopies(void)
{
	@autoreleasepool {
		NSIndexSet *sets[] = {
			[NSIndexSet indexSet],
			[NSIndexSet indexSetWithIndex:7],
			[NSIndexSet indexSetWithIndexesInRange:NSRangeMake(5, 5)],
			ManyIndexSet()
		};

		for (NSUInteger i = 0; i < 4; ++i) {
			NSIndexSet *copy = [sets[i] copy];
			NSMutableIndexSet *mutableCopy = [sets[i] mutableCopy];
			NSUInteger const oldCount = sets[i].count;

			TEST(copy == sets[i]);
			TEST((id)mutableCopy != (id)sets[i]);
			TEST_STR_EQ(object_getClassName(mutableCopy), "NSMutableInlineIndexSet");
			TEST([mutableCopy isEqualToIndexSet:sets[i]]);
			TEST_EQ_UNSIGNED(mutableCopy.hash, sets[i].hash);

			[mutableCopy addIndex:40 + i];
			TEST_EQ_UNSIGNED(sets[i].count, oldCount);
			TEST(![sets[i] containsIndex:40 + i]);
			TEST([mutableCopy containsIndex:40 + i]);
		}
	}
}

int
main(void)
{
	TestEmptyConstruction();
	TestSingleEntryConstruction();
	TestSingleRangeConstruction();
	TestManyRangeConstruction();
	TestInitWithImmutableIndexSet();
	TestInitWithMutableIndexSet();
	TestCopies();

	return TestFinish();
}

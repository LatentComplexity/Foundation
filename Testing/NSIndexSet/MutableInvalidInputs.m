#import <Foundation/NSIndexSet.h>
#import "Test.h"

static void
TestInvalidConstruction(void)
{
	@autoreleasepool {
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSMutableIndexSet alloc] initWithIndex:NSNotFound]);
		TEST_THROWS_NAME(NSRangeException,
			(void)[[NSMutableIndexSet alloc]
				initWithIndexesInRange:NSRangeMake(NSNotFound, 1)]);
	}
}

static void
TestInvalidMethods(void)
{
	@autoreleasepool {
		NSMutableIndexSet *set = [[NSMutableIndexSet alloc] initWithIndex:NSNotFound - 1];
		NSIndexSet *before = [set copy];
		NSIndexSet *nilSet = nil;

		TEST_THROWS_NAME(NSRangeException,
			[set shiftIndexesStartingAtIndex:NSNotFound - 1 by:1]);
		TEST([set isEqualToIndexSet:before]);
		TEST_EQ_UNSIGNED(set.hash, before.hash);

		TEST_THROWS_NAME(NSInvalidArgumentException,
			[set shiftIndexesStartingAtIndex:NSNotFound by:0]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [set addIndexes:nilSet]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [set removeIndexes:nilSet]);
		TEST([set isEqualToIndexSet:before]);
	}

	@autoreleasepool {
		NSMutableIndexSet *set = [[NSMutableIndexSet alloc] initWithIndex:5];
		NSIndexSet *before = [set copy];

		TEST_THROWS_NAME(NSRangeException,
			[set addIndexesInRange:NSRangeMake(NSNotFound - 1, 2)]);
		TEST_THROWS_NAME(NSRangeException,
			[set removeIndexesInRange:NSRangeMake(NSNotFound, 1)]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [set addIndex:NSNotFound]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [set removeIndex:NSNotFound]);
		TEST([set isEqualToIndexSet:before]);
	}
}

int
main(void)
{
	TestInvalidConstruction();
	TestInvalidMethods();

	return TestFinish();
}

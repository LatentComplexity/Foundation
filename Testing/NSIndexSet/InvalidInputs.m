#import <Foundation/NSIndexSet.h>
#import "Test.h"

#import <objc/runtime.h>

#include <stdint.h>

@interface TestIndexSetSubclass : NSIndexSet
@end

@implementation TestIndexSetSubclass
@end

static NSIndexSet *
ManyIndexSet(void)
{
	NSMutableIndexSet *builder = [NSMutableIndexSet indexSet];

	[builder addIndexesInRange:NSRangeMake(1, 2)];
	[builder addIndexesInRange:NSRangeMake(7, 2)];
	[builder addIndexesInRange:NSRangeMake(12, 3)];

	return [builder copy];
}

static void
TestBadInitializers(void)
{
	@autoreleasepool {
		NSIndexSet *nilSet = nil;

		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSIndexSet alloc] initWithIndexSet:nilSet]);
	}

	@autoreleasepool {
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[NSIndexSet indexSetWithIndex:NSNotFound]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSIndexSet alloc] initWithIndex:NSNotFound]);
	}

	@autoreleasepool {
		NSRange const invalidRanges[] = {
			NSRangeMake(NSNotFound, 1),
			NSRangeMake(NSNotFound - 1, 2),
			NSRangeMake(NSUIntegerMax, 0),
			NSRangeMake(NSUIntegerMax, 1)
		};

		for (NSUInteger i = 0; i < sizeof(invalidRanges) / sizeof(invalidRanges[0]); ++i) {
			NSRange const range = invalidRanges[i];

			TEST_THROWS_NAME(NSRangeException,
				(void)[NSIndexSet indexSetWithIndexesInRange:range]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[[NSIndexSet alloc] initWithIndexesInRange:range]);
		}
	}
}

static void
TestAbstractAndSubclassInitialization(void)
{
	@autoreleasepool {
		NSIndexSet *abstract = class_createInstance([NSIndexSet class], 0);
		NSIndexSet *source = [NSIndexSet indexSetWithIndex:3];

		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)[abstract init]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[abstract initWithIndexSet:source]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[abstract initWithIndex:3]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[abstract initWithIndexesInRange:NSRangeMake(3, 2)]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)abstract.count);
	}

	@autoreleasepool {
		TestIndexSetSubclass *subclass = [TestIndexSetSubclass alloc];
		NSIndexSet *source = [NSIndexSet indexSetWithIndex:3];

		TEST_THROWS_NAME(NSUnavailableMethodUsageException, (void)[subclass init]);
		TEST_THROWS_NAME(NSUnavailableMethodUsageException,
			(void)[subclass initWithIndexSet:source]);
		TEST_THROWS_NAME(NSUnavailableMethodUsageException,
			(void)[subclass initWithIndex:3]);
		TEST_THROWS_NAME(NSUnavailableMethodUsageException,
			(void)[subclass initWithIndexesInRange:NSRangeMake(3, 2)]);
		TEST_THROWS_NAME(NSUnavailableMethodUsageException, (void)subclass.count);
	}
}

static void
TestReinitialization(void)
{
	@autoreleasepool {
		NSIndexSet *sets[] = {
			[NSIndexSet indexSet],
			[NSIndexSet indexSetWithIndex:7],
			[NSIndexSet indexSetWithIndexesInRange:NSRangeMake(5, 5)],
			ManyIndexSet()
		};
		NSIndexSet *source = [NSIndexSet indexSetWithIndex:3];

		for (NSUInteger i = 0; i < sizeof(sets) / sizeof(sets[0]); ++i) {
			TEST_THROWS_NAME(NSUnavailableMethodUsageException, (void)[sets[i] init]);
			TEST_THROWS_NAME(NSUnavailableMethodUsageException,
				(void)[sets[i] initWithIndexSet:source]);
			TEST_THROWS_NAME(NSUnavailableMethodUsageException,
				(void)[sets[i] initWithIndex:3]);
			TEST_THROWS_NAME(NSUnavailableMethodUsageException,
				(void)[sets[i] initWithIndexesInRange:NSRangeMake(3, 2)]);
		}
	}
}

static void
TestUninitializedTemplateMethods(void)
{
	@autoreleasepool {
		NSIndexSet *set = [NSIndexSet alloc];
		NSIndexSet *argument = [NSIndexSet indexSetWithIndex:3];
		NSUInteger buffer[2] = { 0, 0 };
		NSRange cursor = NSRangeMake(0, 8);

		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)[set copy]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)[set mutableCopy]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)set.count);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)set.firstIndex);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)set.lastIndex);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set getIndexes:buffer maxCount:2 inIndexRange:&cursor]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)[set containsIndex:3]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)[set containsIndexes:argument]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set containsIndexesInRange:NSRangeMake(2, 3)]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set intersectsIndexesInRange:NSRangeMake(2, 3)]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set indexGreaterThanIndex:3]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set indexLessThanIndex:3]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set indexGreaterThanOrEqualToIndex:3]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set indexLessThanOrEqualToIndex:3]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set countOfIndexesInRange:NSRangeMake(2, 3)]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set indexPassingTest:^bool(NSUInteger index, bool *stop) {
				(void)index;
				(void)stop;
				return true;
			}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set indexWithOptions:NSEnumerationReverse
				passingTest:^bool(NSUInteger index, bool *stop) {
					(void)index;
					(void)stop;
					return true;
				}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set indexInRange:NSRangeMake(2, 3) options:NSEnumerationNoOptions
				passingTest:^bool(NSUInteger index, bool *stop) {
					(void)index;
					(void)stop;
					return true;
				}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set indexesPassingTest:^bool(NSUInteger index, bool *stop) {
				(void)index;
				(void)stop;
				return true;
			}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set indexesWithOptions:NSEnumerationReverse
				passingTest:^bool(NSUInteger index, bool *stop) {
					(void)index;
					(void)stop;
					return true;
				}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set indexesInRange:NSRangeMake(2, 3) options:NSEnumerationNoOptions
				passingTest:^bool(NSUInteger index, bool *stop) {
					(void)index;
					(void)stop;
					return true;
				}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			[set enumerateIndexesUsingBlock:^(NSUInteger index, bool *stop) {
				(void)index;
				(void)stop;
			}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			[set enumerateIndexesWithOptions:NSEnumerationReverse
				usingBlock:^(NSUInteger index, bool *stop) {
					(void)index;
					(void)stop;
				}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			[set enumerateIndexesInRange:NSRangeMake(2, 3) options:NSEnumerationNoOptions
				usingBlock:^(NSUInteger index, bool *stop) {
					(void)index;
					(void)stop;
				}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			[set enumerateRangesUsingBlock:^(NSRange range, bool *stop) {
				(void)range;
				(void)stop;
			}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			[set enumerateRangesWithOptions:NSEnumerationReverse
				usingBlock:^(NSRange range, bool *stop) {
					(void)range;
					(void)stop;
				}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			[set enumerateRangesInRange:NSRangeMake(2, 3) options:NSEnumerationNoOptions
				usingBlock:^(NSRange range, bool *stop) {
					(void)range;
					(void)stop;
				}]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)set.hash);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException,
			(void)[set isEqualToIndexSet:argument]);
		TEST_THROWS_NAME(NSUninitializedObjectUsageException, (void)[set isEqual:argument]);
	}
}

static void
TestInvalidInputsOnEveryRepresentation(void)
{
	@autoreleasepool {
		NSIndexSet *sets[] = {
			[NSIndexSet indexSet],
			[NSIndexSet indexSetWithIndex:7],
			[NSIndexSet indexSetWithIndexesInRange:NSRangeMake(5, 5)],
			ManyIndexSet()
		};
		NSIndexSet *nilSet = nil;
		NSUInteger *nullBuffer = nullptr;
		bool (^nilPredicate)(NSUInteger, bool *) = nil;
		void (^nilIndexBlock)(NSUInteger, bool *) = nil;
		void (^nilRangeBlock)(NSRange, bool *) = nil;
		NSEnumerationOptions const invalidOptions = (NSEnumerationOptions)(1UL << 2);
		NSRange const invalidRange = NSRangeMake(NSNotFound, 1);
		NSRange const overflowingRange = NSRangeMake(NSUIntegerMax, 1);

		for (NSUInteger i = 0; i < sizeof(sets) / sizeof(sets[0]); ++i) {
			NSIndexSet *set = sets[i];
			NSRange badCursor = invalidRange;
			NSRange overflowingCursor = overflowingRange;

			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set isEqualToIndexSet:nilSet]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set getIndexes:nullBuffer maxCount:0 inIndexRange:nullptr]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[set getIndexes:(NSUInteger[1]){ 0 } maxCount:1 inIndexRange:&badCursor]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[set getIndexes:(NSUInteger[1]){ 0 } maxCount:1
					inIndexRange:&overflowingCursor]);

			TEST_THROWS_NAME(NSInvalidArgumentException, (void)[set containsIndex:NSNotFound]);
			TEST_THROWS_NAME(NSInvalidArgumentException, (void)[set containsIndexes:nilSet]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexGreaterThanIndex:NSNotFound]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexLessThanIndex:NSNotFound]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexGreaterThanOrEqualToIndex:NSNotFound]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexLessThanOrEqualToIndex:NSNotFound]);

			TEST_THROWS_NAME(NSRangeException,
				(void)[set containsIndexesInRange:invalidRange]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[set containsIndexesInRange:overflowingRange]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[set intersectsIndexesInRange:invalidRange]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[set intersectsIndexesInRange:overflowingRange]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[set countOfIndexesInRange:invalidRange]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[set countOfIndexesInRange:overflowingRange]);

			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexPassingTest:nilPredicate]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexWithOptions:NSEnumerationNoOptions passingTest:nilPredicate]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexInRange:NSRangeZero options:NSEnumerationNoOptions
					passingTest:nilPredicate]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexesPassingTest:nilPredicate]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexesWithOptions:NSEnumerationNoOptions passingTest:nilPredicate]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexesInRange:NSRangeZero options:NSEnumerationNoOptions
					passingTest:nilPredicate]);

			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexWithOptions:invalidOptions
					passingTest:^bool(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
						return true;
					}]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexesWithOptions:invalidOptions
					passingTest:^bool(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
						return true;
					}]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexInRange:NSRangeZero options:invalidOptions
					passingTest:^bool(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
						return true;
					}]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[set indexesInRange:NSRangeZero options:invalidOptions
					passingTest:^bool(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
						return true;
					}]);

			TEST_THROWS_NAME(NSRangeException,
				(void)[set indexInRange:invalidRange options:NSEnumerationNoOptions
					passingTest:^bool(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
						return true;
					}]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[set indexInRange:overflowingRange options:NSEnumerationNoOptions
					passingTest:^bool(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
						return true;
					}]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[set indexesInRange:invalidRange options:NSEnumerationNoOptions
					passingTest:^bool(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
						return true;
					}]);
			TEST_THROWS_NAME(NSRangeException,
				(void)[set indexesInRange:overflowingRange options:NSEnumerationNoOptions
					passingTest:^bool(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
						return true;
					}]);

			TEST_THROWS_NAME(NSInvalidArgumentException,
				[set enumerateIndexesUsingBlock:nilIndexBlock]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				[set enumerateIndexesWithOptions:NSEnumerationNoOptions usingBlock:nilIndexBlock]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				[set enumerateIndexesInRange:NSRangeZero options:NSEnumerationNoOptions
					usingBlock:nilIndexBlock]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				[set enumerateRangesUsingBlock:nilRangeBlock]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				[set enumerateRangesWithOptions:NSEnumerationNoOptions usingBlock:nilRangeBlock]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				[set enumerateRangesInRange:NSRangeZero options:NSEnumerationNoOptions
					usingBlock:nilRangeBlock]);

			TEST_THROWS_NAME(NSInvalidArgumentException,
				[set enumerateIndexesWithOptions:invalidOptions
					usingBlock:^(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
					}]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				[set enumerateRangesWithOptions:invalidOptions
					usingBlock:^(NSRange range, bool *stop) {
						(void)range;
						(void)stop;
					}]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				[set enumerateIndexesInRange:NSRangeZero options:invalidOptions
					usingBlock:^(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
					}]);
			TEST_THROWS_NAME(NSInvalidArgumentException,
				[set enumerateRangesInRange:NSRangeZero options:invalidOptions
					usingBlock:^(NSRange range, bool *stop) {
						(void)range;
						(void)stop;
					}]);

			TEST_THROWS_NAME(NSRangeException,
				[set enumerateIndexesInRange:invalidRange options:NSEnumerationNoOptions
					usingBlock:^(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
					}]);
			TEST_THROWS_NAME(NSRangeException,
				[set enumerateIndexesInRange:overflowingRange options:NSEnumerationNoOptions
					usingBlock:^(NSUInteger index, bool *stop) {
						(void)index;
						(void)stop;
					}]);
			TEST_THROWS_NAME(NSRangeException,
				[set enumerateRangesInRange:invalidRange options:NSEnumerationNoOptions
					usingBlock:^(NSRange range, bool *stop) {
						(void)range;
						(void)stop;
					}]);
			TEST_THROWS_NAME(NSRangeException,
				[set enumerateRangesInRange:overflowingRange options:NSEnumerationNoOptions
					usingBlock:^(NSRange range, bool *stop) {
						(void)range;
						(void)stop;
					}]);
		}
	}
}

int
main(void)
{
	TestBadInitializers();
	TestAbstractAndSubclassInitialization();
	TestReinitialization();
	TestUninitializedTemplateMethods();
	TestInvalidInputsOnEveryRepresentation();

	return TestFinish();
}

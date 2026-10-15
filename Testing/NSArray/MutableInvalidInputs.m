#import <Foundation/NSArray.h>
#import <Foundation/NSIndexSet.h>
#import "Test.h"

@interface HugeArray : NSArray
@end

@implementation HugeArray

- (NSUInteger)count
{
	return NSUIntegerMax;
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	(void)index;
	return @"x";
}

@end

@interface NilArray : NSArray
@end

@implementation NilArray

- (NSUInteger)count
{
	return 1;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	(void)index;
	return nil;
}

#pragma clang diagnostic pop

@end

static NSMutableArray *
Array(void)
{
	return [[NSArray arrayWithObjects:(id[]){ @"a", @"b", @"c" } count:3] mutableCopy];
}

static NSMutableArray *
EmptyArray(void)
{
	return [[NSArray array] mutableCopy];
}

static void
TestNilArguments(void)
{
	NSArray *nilArray = nil;
	NSIndexSet *nilIndexes = nil;
	id nilObject = nil;

	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() addObject:nilObject]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() addObjectsFromArray:nilArray]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() insertObject:nilObject atIndex:0]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() insertObjects:nilArray
		atIndexes:[NSIndexSet indexSet]]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() insertObjects:[NSArray array]
		atIndexes:nilIndexes]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() removeObjectsAtIndexes:nilIndexes]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() removeObjectsInArray:nilArray]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() replaceObjectsAtIndexes:nilIndexes
		withObjects:[NSArray array]]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() replaceObjectsAtIndexes:[NSIndexSet indexSet]
		withObjects:nilArray]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() replaceObjectAtIndex:0 withObject:nilObject]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() replaceObjectsInRange:NSRangeZero
		withObjectsFromArray:nilArray]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() setObject:nilObject atIndexedSubscript:0]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() setArray:nilArray]);
}

static void
TestInvalidIndexesAndRanges(void)
{
	TEST_THROWS_NAME(NSRangeException, [Array() insertObject:@"x" atIndex:4]);
	TEST_THROWS_NAME(NSRangeException, [Array() exchangeObjectAtIndex:3 withObjectAtIndex:0]);
	TEST_THROWS_NAME(NSRangeException, [Array() exchangeObjectAtIndex:0 withObjectAtIndex:3]);
	TEST_THROWS_NAME(NSRangeException, [Array() removeObjectAtIndex:3]);
	TEST_THROWS_NAME(NSRangeException, [Array() removeObject:@"a" inRange:NSRangeMake(2, 2)]);
	TEST_THROWS_NAME(NSRangeException, [Array() removeObjectIdenticalTo:@"a"
		inRange:NSRangeMake(NSUIntegerMax, 1)]);
	TEST_THROWS_NAME(NSRangeException, [Array() removeObjectsInRange:NSRangeMake(3, 1)]);
	TEST_THROWS_NAME(NSRangeException, [Array() removeObjectsAtIndexes:
		[NSIndexSet indexSetWithIndex:3]]);
	TEST_THROWS_NAME(NSRangeException, [Array() insertObjects:[NSArray arrayWithObject:@"x"]
		atIndexes:[NSIndexSet indexSetWithIndex:4]]);
	TEST_THROWS_NAME(NSRangeException, [Array() replaceObjectsAtIndexes:
		[NSIndexSet indexSetWithIndex:3] withObjects:[NSArray arrayWithObject:@"x"]]);
	TEST_THROWS_NAME(NSRangeException, [Array() replaceObjectAtIndex:3 withObject:@"x"]);
	TEST_THROWS_NAME(NSRangeException, [Array() replaceObjectsInRange:NSRangeMake(4, 0)
		withObjectsFromArray:[NSArray array]]);
	TEST_THROWS_NAME(NSRangeException, [Array() replaceObjectsInRange:NSRangeZero
		withObjectsFromArray:[NSArray arrayWithObject:@"x"] range:NSRangeMake(1, 1)]);
	TEST_THROWS_NAME(NSRangeException, [Array() setObject:@"x" atIndexedSubscript:4]);
	TEST_THROWS_NAME(NSRangeException, [EmptyArray() removeLastObject]);
}

static void
TestInvalidCountsAndForeignArrays(void)
{
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() insertObjects:[NSArray array]
		atIndexes:[NSIndexSet indexSetWithIndex:0]]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() replaceObjectsAtIndexes:
		[NSIndexSet indexSetWithIndex:0] withObjects:[NSArray array]]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() addObjectsFromArray:[HugeArray new]]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() setArray:[HugeArray new]]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() addObjectsFromArray:[NilArray new]]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() insertObjects:[NilArray new]
		atIndexes:[NSIndexSet indexSetWithIndex:0]]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() replaceObjectsAtIndexes:
		[NSIndexSet indexSetWithIndex:0] withObjects:[NilArray new]]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() replaceObjectsInRange:NSRangeZero
		withObjectsFromArray:[NilArray new]]);
	TEST_THROWS_NAME(NSInvalidArgumentException, [Array() setArray:[NilArray new]]);
}

int
main(void)
{
	TestNilArguments();
	TestInvalidIndexesAndRanges();
	TestInvalidCountsAndForeignArrays();

	return TestFinish();
}

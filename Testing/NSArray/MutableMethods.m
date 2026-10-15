#import <Foundation/NSArray.h>
#import <Foundation/NSIndexSet.h>
#import "Test.h"

#import <objc/runtime.h>

@interface TestArray : NSArray

- (instancetype)initWithObjects:(id __unsafe_unretained const *)objects count:(NSUInteger)count;

@end

@implementation TestArray {
	NSArray *_contents;
}

- (instancetype)initWithObjects:(id __unsafe_unretained const *)objects count:(NSUInteger)count
{
	self = [super init];
	if (self != nil)
		_contents = [NSArray arrayWithObjects:objects count:count];

	return self;
}

- (NSUInteger)count
{
	return _contents.count;
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	return _contents[index];
}

@end

@interface TestBox : NSObject

- (instancetype)initWithValue:(NSUInteger)value;

@end


@implementation TestBox {
	NSUInteger _value;
}

- (instancetype)initWithValue:(NSUInteger)value
{
	self = [super init];
	if (self != nil)
		_value = value;

	return self;
}

- (NSUInteger)hash
{
	return _value;
}

- (bool)isEqual:(nullable id)other
{
	return object_getClass(other) == [TestBox class] && ((TestBox *)other)->_value == _value;
}

@end

static NSMutableArray *
MutableArray(id __unsafe_unretained const *objects, NSUInteger count)
{
	return [[NSArray arrayWithObjects:objects count:count] mutableCopy];
}

static TestArray *
ForeignArray(id __unsafe_unretained const *objects, NSUInteger count)
{
	return [[TestArray alloc] initWithObjects:objects count:count];
}

static void
TestContents(NSArray *array, id __unsafe_unretained const *expected, NSUInteger count)
{
	TEST_EQ_UNSIGNED(array.count, count);
	TEST(array.firstObject == (count == 0 ? nil : expected[0]));
	TEST(array.lastObject == (count == 0 ? nil : expected[count - 1]));

	for (NSUInteger i = 0; i < count; ++i)
		TEST_OBJ_EQ(array[i], expected[i]);
}

static NSMutableIndexSet *
IndexSet(NSUInteger const *indexes, NSUInteger count)
{
	NSMutableIndexSet *set = [NSMutableIndexSet indexSet];

	for (NSUInteger i = 0; i < count; ++i)
		[set addIndex:indexes[i]];

	return set;
}

static void
TestImmutableSurfaceAndCopies(void)
{
	@autoreleasepool {
		NSMutableArray *empty = [[NSArray array] mutableCopy];
		NSArray *emptyCopy = [empty copy];

		TEST_STR_EQ(object_getClassName(empty), "NSMutableInlineArray");
		TEST_STR_EQ(object_getClassName(emptyCopy), "NSZeroArray");
		TestContents(empty, nullptr, 0);
		TEST_EQ_UNSIGNED(empty.hash, emptyCopy.hash);

		NSMutableArray *single = [[NSArray arrayWithObject:@"a"] mutableCopy];
		NSArray *singleCopy = [single copy];

		TEST_STR_EQ(object_getClassName(singleCopy), "NSSingleEntryArray");
		TestContents(single, (id[]){ @"a" }, 1);
		TEST([single isEqualToArray:singleCopy]);
		TEST([singleCopy isEqualToArray:single]);
	}

	@autoreleasepool {
		NSMutableArray *array = MutableArray((id[]){ @"a", @"b", @"c", @"d" }, 4);
		NSArray *copy = [array copy];
		NSMutableArray *mutableCopy = [array mutableCopy];
		NSArray *full = [array subarrayWithRange:NSRangeMake(0, 4)];
		NSArray *middle = [array subarrayWithRange:NSRangeMake(1, 2)];
		NSArray *selected = [array objectsAtIndexes:
			IndexSet((NSUInteger[]){ 0, 2, 3 }, 3)];
		id __unsafe_unretained copied[2] = { nil, nil };
		__block NSUInteger visits = 0;

		TEST_STR_EQ(object_getClassName(copy), "NSInlineArray");
		TEST_STR_EQ(object_getClassName(mutableCopy), "NSMutableInlineArray");
		TEST((id)copy != (id)array);
		TEST((id)full != (id)array);
		TEST([array isEqualToArray:copy]);
		TEST([copy isEqualToArray:array]);
		TEST_EQ_UNSIGNED(array.hash, copy.hash);
		TestContents(middle, (id[]){ @"b", @"c" }, 2);
		TestContents(selected, (id[]){ @"a", @"c", @"d" }, 3);

		[array getObjects:copied range:NSRangeMake(1, 2)];
		TEST_OBJ_EQ(copied[0], @"b");
		TEST_OBJ_EQ(copied[1], @"c");
		TEST_EQ_UNSIGNED([array indexOfObject:@"c"], 2);
		TEST_EQ_UNSIGNED([array indexOfObjectIdenticalTo:@"d"], 3);
		TEST([array containsObject:@"b"]);
		TEST_EQ_UNSIGNED([array indexOfObjectWithOptions:NSEnumerationReverse
			passingTest:^(id object, NSUInteger index, bool *stop) {
				(void)stop;
				return (bool)([(id<NSObject>)object isEqual:@"b"] && index == 1);
			}], 1);
		[array enumerateObjectsUsingBlock:^(id object, NSUInteger index, bool *stop) {
			(void)object;
			(void)index;
			(void)stop;
			++visits;
		}];
		TEST_EQ_UNSIGNED(visits, 4);

		[array addObject:@"e"];
		[mutableCopy addObject:@"f"];
		TestContents(copy, (id[]){ @"a", @"b", @"c", @"d" }, 4);
		TestContents(full, (id[]){ @"a", @"b", @"c", @"d" }, 4);
		TestContents(middle, (id[]){ @"b", @"c" }, 2);
		TestContents(array, (id[]){ @"a", @"b", @"c", @"d", @"e" }, 5);
		TestContents(mutableCopy, (id[]){ @"a", @"b", @"c", @"d", @"f" }, 5);
		TEST_EQ_UNSIGNED(array.hash,
			([NSArray arrayWithObjects:(id[]){ @"a", @"b", @"c", @"d", @"e" } count:5].hash));
	}
}

static void
TestInsertionAndExchange(void)
{
	@autoreleasepool {
		NSMutableArray *array = MutableArray((id[]){ @"a", @"c", @"e" }, 3);
		TestArray *foreign = ForeignArray((id[]){ @"b", @"d" }, 2);

		[array insertObjects:foreign atIndexes:IndexSet((NSUInteger[]){ 1, 3 }, 2)];
		TestContents(array, (id[]){ @"a", @"b", @"c", @"d", @"e" }, 5);

		[array insertObject:@"z" atIndex:0];
		[array setObject:@"f" atIndexedSubscript:array.count];
		[array exchangeObjectAtIndex:0 withObjectAtIndex:array.count - 1];
		TestContents(array, (id[]){ @"f", @"a", @"b", @"c", @"d", @"e", @"z" }, 7);
	}

	@autoreleasepool {
		NSMutableArray *array = MutableArray((id[]){ @"a", @"b" }, 2);

		[array addObjectsFromArray:array];
		TestContents(array, (id[]){ @"a", @"b", @"a", @"b" }, 4);
	}

	@autoreleasepool {
		NSMutableArray *array = MutableArray((id[]){ @"a", @"b" }, 2);

		[array insertObjects:array atIndexes:IndexSet((NSUInteger[]){ 1, 3 }, 2)];
		TestContents(array, (id[]){ @"a", @"a", @"b", @"b" }, 4);
	}

	@autoreleasepool {
		NSMutableArray *array = MutableArray((id[]){ @"a" }, 1);
		TestArray *foreign = ForeignArray((id[]){ @"b", @"c" }, 2);

		[array addObjectsFromArray:foreign];
		TestContents(array, (id[]){ @"a", @"b", @"c" }, 3);
	}

	@autoreleasepool {
		NSMutableArray *array = MutableArray((id[]){ @"a", @"b", @"c", @"d" }, 4);
		NSArray *slice = [array subarrayWithRange:NSRangeMake(1, 2)];

		[array insertObjects:slice atIndexes:IndexSet((NSUInteger[]){ 0, 5 }, 2)];
		TestContents(array, (id[]){ @"b", @"a", @"b", @"c", @"d", @"c" }, 6);
		TestContents(slice, (id[]){ @"b", @"c" }, 2);
	}
}

static void
TestRemovals(void)
{
	@autoreleasepool {
		TestBox *oneA = [[TestBox alloc] initWithValue:1];
		TestBox *oneB = [[TestBox alloc] initWithValue:1];
		TestBox *two = [[TestBox alloc] initWithValue:2];
		NSMutableArray *array = MutableArray((id[]){ oneA, oneB, two, oneA }, 4);

		[array removeObjectIdenticalTo:oneA inRange:NSRangeMake(1, 3)];
		TestContents(array, (id[]){ oneA, oneB, two }, 3);
		[array removeObject:oneB];
		TestContents(array, (id[]){ two }, 1);
	}

	@autoreleasepool {
		NSMutableArray *array = MutableArray(
			(id[]){ @"a", @"b", @"c", @"d", @"e", @"f", @"g" }, 7);

		[array removeObjectsAtIndexes:IndexSet((NSUInteger[]){ 1, 2, 5 }, 3)];
		TestContents(array, (id[]){ @"a", @"d", @"e", @"g" }, 4);
		[array removeObjectsInRange:NSRangeMake(1, 2)];
		[array removeLastObject];
		TestContents(array, (id[]){ @"a" }, 1);
		[array removeAllObjects];
		TestContents(array, nullptr, 0);
	}

	@autoreleasepool {
		NSMutableArray *array = MutableArray((id[]){ @"a", @"b", @"c", @"b", @"d" }, 5);
		TestArray *foreign = ForeignArray((id[]){ @"b", @"d" }, 2);

		[array removeObjectsInArray:foreign];
		TestContents(array, (id[]){ @"a", @"c" }, 2);
		[array removeObjectAtIndex:0];
		TestContents(array, (id[]){ @"c" }, 1);
		[array removeObjectsInArray:array];
		TestContents(array, nullptr, 0);
	}
}

static void
TestReplacementAndSetArray(void)
{
	@autoreleasepool {
		NSMutableArray *array = MutableArray((id[]){ @"a", @"b", @"c" }, 3);
		NSArray *snapshot = [array copy];

		[array replaceObjectAtIndex:1 withObject:array[2]];
		TestContents(array, (id[]){ @"a", @"c", @"c" }, 3);
		TestContents(snapshot, (id[]){ @"a", @"b", @"c" }, 3);
	}

	@autoreleasepool {
		NSMutableArray *array = MutableArray((id[]){ @"a", @"b", @"c", @"d" }, 4);
		TestArray *foreign = ForeignArray((id[]){ @"x", @"y" }, 2);

		[array replaceObjectsAtIndexes:IndexSet((NSUInteger[]){ 1, 3 }, 2) withObjects:foreign];
		TestContents(array, (id[]){ @"a", @"x", @"c", @"y" }, 4);
		[array replaceObjectsInRange:NSRangeMake(1, 2)
			withObjectsFromArray:MutableArray((id[]){ @"m", @"n", @"o" }, 3)];
		TestContents(array, (id[]){ @"a", @"m", @"n", @"o", @"y" }, 5);
		[array replaceObjectsInRange:NSRangeMake(1, 3)
			withObjectsFromArray:ForeignArray((id[]){ @"q", @"r", @"s" }, 3)
			range:NSRangeMake(1, 1)];
		TestContents(array, (id[]){ @"a", @"r", @"y" }, 3);
	}

	@autoreleasepool {
		NSMutableArray *array = MutableArray((id[]){ @"a", @"b", @"c" }, 3);

		[array replaceObjectsInRange:NSRangeMake(1, 1) withObjectsFromArray:array];
		TestContents(array, (id[]){ @"a", @"a", @"b", @"c", @"c" }, 5);
		[array replaceObjectsInRange:NSRangeMake(0, 2)
			withObjectsFromArray:array range:NSRangeMake(3, 2)];
		TestContents(array, (id[]){ @"c", @"c", @"b", @"c", @"c" }, 5);
	}

	@autoreleasepool {
		NSArray *source = [NSArray arrayWithObjects:(id[]){ @"a", @"b", @"c" } count:3];
		NSMutableArray *array = MutableArray((id[]){ @"x" }, 1);

		[array setArray:source];
		[array setObject:@"z" atIndexedSubscript:1];
		TestContents(source, (id[]){ @"a", @"b", @"c" }, 3);
		TestContents(array, (id[]){ @"a", @"z", @"c" }, 3);

		[array setArray:ForeignArray((id[]){ @"q", @"r" }, 2)];
		TestContents(array, (id[]){ @"q", @"r" }, 2);
		[array setArray:[NSArray array]];
		TestContents(array, nullptr, 0);
	}

	/* Exercise the unique-buffer branch whose existing capacity cannot hold a foreign source. */
	@autoreleasepool {
		NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:1];
		TestArray *source = ForeignArray((id[]){ @"a", @"b", @"c", @"d" }, 4);

		[array addObject:@"old"];
		[array setArray:source];
		TestContents(array, (id[]){ @"a", @"b", @"c", @"d" }, 4);

		[array addObject:@"e"];
		TestContents(array, (id[]){ @"a", @"b", @"c", @"d", @"e" }, 5);
		TestContents(source, (id[]){ @"a", @"b", @"c", @"d" }, 4);
	}
}

int
main(void)
{
	TestImmutableSurfaceAndCopies();
	TestInsertionAndExchange();
	TestRemovals();
	TestReplacementAndSetArray();

	return TestFinish();
}

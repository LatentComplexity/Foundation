#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
#import "Test.h"

#include <objc/objc-arc.h>

static NSUInteger CopyingBoxCopies;
static NSUInteger CopyingBoxLiveCount;
static NSUInteger LifetimeSentinelDeallocations;
static __weak id LifetimeWeakObject;

@interface CopyingBox : NSObject <NSCopying>

- (instancetype)initWithValue:(NSUInteger)value;

@end

@implementation CopyingBox {
	NSUInteger _value;
}

- (instancetype)initWithValue:(NSUInteger)value
{
	self = [super init];
	if (self != nil) {
		_value = value;
		++CopyingBoxLiveCount;
	}

	return self;
}

- (id)copy
{
	++CopyingBoxCopies;
	return [[CopyingBox alloc] initWithValue:_value];
}

- (bool)isEqual:(nullable id)other
{
	return object_getClass(other) == [CopyingBox class] && ((CopyingBox *)other)->_value == _value;
}

- (void)dealloc
{
	--CopyingBoxLiveCount;
}

@end

@interface LifetimeSentinel : NSObject
@end

@implementation LifetimeSentinel

- (void)dealloc
{
	++LifetimeSentinelDeallocations;
}

@end

static void
SetLifetimeWeakObject(id object)
{
	LifetimeWeakObject = object;
}

static bool
LifetimeWeakObjectIsAlive(void)
{
	id strongObject = LifetimeWeakObject;
	return strongObject != nil;
}

static void
TestContents(NSArray *array, id __unsafe_unretained const *expected, NSUInteger count)
{
	TEST_EQ_UNSIGNED(array.count, count);

	for (NSUInteger i = 0; i < count; ++i)
		TEST(array[i] == expected[i]);
}

static void
TestEnumeratorsForArray(NSArray *array, id __unsafe_unretained const *expected, NSUInteger count)
{
	NSEnumerator *forward = [array objectEnumerator];
	NSEnumerator *reverse = [array reverseObjectEnumerator];

	for (NSUInteger i = 0; i < count; ++i) {
		TEST([forward nextObject] == expected[i]);
		TEST([reverse nextObject] == expected[count - i - 1]);
	}

	TEST([forward nextObject] == nil);
	TEST([forward nextObject] == nil);
	TEST([reverse nextObject] == nil);
	TEST([reverse nextObject] == nil);

	forward = [array objectEnumerator];
	reverse = [array reverseObjectEnumerator];
	TestContents(forward.allObjects, expected, count);

	NSArray *reverseObjects = reverse.allObjects;
	TEST_EQ_UNSIGNED(reverseObjects.count, count);
	for (NSUInteger i = 0; i < count; ++i)
		TEST(reverseObjects[i] == expected[count - i - 1]);

	TEST([forward nextObject] == nil);
	TEST([reverse nextObject] == nil);
}

static void
TestEnumerators(void)
{
	@autoreleasepool {
		NSArray *zero = [NSArray array];
		NSArray *single = [NSArray arrayWithObject:@"a"];
		NSArray *inlineArray = [NSArray arrayWithObjects:
			(id[]){ @"a", @"b", @"c", @"d" } count:4];
		NSArray *subrange = [inlineArray subarrayWithRange:NSRangeMake(1, 2)];
		NSMutableArray *mutable = [inlineArray mutableCopy];

		TestEnumeratorsForArray(zero, nullptr, 0);
		TestEnumeratorsForArray(single, (id[]){ @"a" }, 1);
		TestEnumeratorsForArray(inlineArray, (id[]){ @"a", @"b", @"c", @"d" }, 4);
		TestEnumeratorsForArray(subrange, (id[]){ @"b", @"c" }, 2);
		TestEnumeratorsForArray(mutable, (id[]){ @"a", @"b", @"c", @"d" }, 4);
	}
}

static void
TestCopyItems(void)
{
	CopyingBoxCopies = 0;
	CopyingBoxLiveCount = 0;

	@autoreleasepool {
		CopyingBox *object = [[CopyingBox alloc] initWithValue:1];
		NSArray *source = [[NSArray alloc] initWithObjects:
			(id __unsafe_unretained[]){ object } count:1];
		NSArray *immutable = [[NSArray alloc] initWithArray:source copyItems:true];
		NSMutableArray *mutable = [[NSMutableArray alloc] initWithArray:source copyItems:true];
		NSArray *uncopied = [[NSArray alloc] initWithArray:source copyItems:false];
		NSMutableArray *mutableUncopied = [[NSMutableArray alloc] initWithArray:source copyItems:false];

		TEST_EQ_UNSIGNED(CopyingBoxCopies, 2);
		TEST_EQ_UNSIGNED(CopyingBoxLiveCount, 3);
		TEST(immutable[0] != object);
		TEST(mutable[0] != object);
		TEST(immutable[0] != mutable[0]);
		TEST_OBJ_EQ(immutable[0], object);
		TEST_OBJ_EQ(mutable[0], object);
		TEST(uncopied == source);
		TEST(uncopied[0] == object);
		TEST(mutableUncopied[0] == object);
	}

	TEST_EQ_UNSIGNED(CopyingBoxLiveCount, 0);

	@autoreleasepool {
		CopyingBox *first = [[CopyingBox alloc] initWithValue:1];
		CopyingBox *second = [[CopyingBox alloc] initWithValue:2];
		NSArray *source = [[NSArray alloc] initWithObjects:
			(id __unsafe_unretained[]){ first, second } count:2];
		NSArray *immutable = [[NSArray alloc] initWithArray:source copyItems:true];
		NSMutableArray *mutable = [[NSMutableArray alloc] initWithArray:source copyItems:true];

		TEST_EQ_UNSIGNED(CopyingBoxCopies, 6);
		TEST_EQ_UNSIGNED(CopyingBoxLiveCount, 6);
		TEST(immutable[0] != first);
		TEST(immutable[1] != second);
		TEST(mutable[0] != first);
		TEST(mutable[1] != second);
		TEST_OBJ_EQ(immutable[0], first);
		TEST_OBJ_EQ(immutable[1], second);
		TEST_OBJ_EQ(mutable[0], first);
		TEST_OBJ_EQ(mutable[1], second);
	}

	TEST_EQ_UNSIGNED(CopyingBoxLiveCount, 0);
}

static void
TestSingletonLastOwner(void)
{
	LifetimeSentinelDeallocations = 0;

	@autoreleasepool {
		LifetimeSentinel *object = [LifetimeSentinel new];
		LifetimeSentinel *const __unsafe_unretained probe = object;
		id __unsafe_unretained objects[] = { object };
		size_t const initialRetainCount = object_getRetainCount_np(object);
		NSArray *array = [[NSArray alloc] initWithObjects:objects count:1];

		SetLifetimeWeakObject(object);
		TEST_EQ_UNSIGNED(array.count, 1);
		TEST_EQ_UNSIGNED(object_getRetainCount_np(probe), initialRetainCount + 1);

		object = nil;
		TEST(LifetimeWeakObjectIsAlive());
		TEST_EQ_UNSIGNED(object_getRetainCount_np(probe), 1);

		array = nil;
		TEST(LifetimeWeakObjectIsAlive() == false);
		TEST_EQ_UNSIGNED(LifetimeSentinelDeallocations, 1);
	}
}

static void
TestInlineRetainsAndCopyOnWrite(void)
{
	LifetimeSentinelDeallocations = 0;

	@autoreleasepool {
		LifetimeSentinel *object = [LifetimeSentinel new];
		LifetimeSentinel *const __unsafe_unretained probe = object;
		id __unsafe_unretained objects[] = { object, object, @"anchor" };
		size_t const initialRetainCount = object_getRetainCount_np(object);
		NSMutableArray *array = [[NSMutableArray alloc] initWithObjects:objects count:3];
		NSArray *snapshot = [array copy];

		SetLifetimeWeakObject(object);
		TEST_EQ_UNSIGNED(object_getRetainCount_np(probe), initialRetainCount + 2);

		[array removeObjectAtIndex:1];
		TEST_EQ_UNSIGNED(object_getRetainCount_np(probe), initialRetainCount + 3);
		TEST_EQ_UNSIGNED(array.count, 2);
		TEST_EQ_UNSIGNED(snapshot.count, 3);

		object = nil;
		TEST(LifetimeWeakObjectIsAlive());
		TEST_EQ_UNSIGNED(object_getRetainCount_np(probe), 3);

		array = nil;
		TEST(LifetimeWeakObjectIsAlive());
		TEST_EQ_UNSIGNED(object_getRetainCount_np(probe), 2);

		snapshot = nil;
		TEST(LifetimeWeakObjectIsAlive() == false);
		TEST_EQ_UNSIGNED(LifetimeSentinelDeallocations, 1);
	}
}

static void
TestEnumeratorLastOwner(void)
{
	LifetimeSentinelDeallocations = 0;

	@autoreleasepool {
		LifetimeSentinel *object = [LifetimeSentinel new];
		LifetimeSentinel *const __unsafe_unretained probe = object;
		id anchor = @"anchor";
		id __unsafe_unretained objects[] = { object, anchor };
		NSMutableArray *array = [[NSMutableArray alloc] initWithObjects:objects count:2];
		NSEnumerator *enumerator = [array reverseObjectEnumerator];

		SetLifetimeWeakObject(object);
		object = nil;
		array = nil;
		TEST(LifetimeWeakObjectIsAlive());
		TEST_EQ_UNSIGNED(object_getRetainCount_np(probe), 1);

		TEST([enumerator nextObject] == anchor);
		TEST([enumerator nextObject] == probe);
		TEST(LifetimeWeakObjectIsAlive());
		TEST_EQ_UNSIGNED(object_getRetainCount_np(probe), 1);

		TEST([enumerator nextObject] == nil);
		TEST(LifetimeWeakObjectIsAlive() == false);
		TEST_EQ_UNSIGNED(LifetimeSentinelDeallocations, 1);
	}
}

int
main(void)
{
	TestEnumerators();
	TestCopyItems();
	TestSingletonLastOwner();
	TestInlineRetainsAndCopyOnWrite();
	TestEnumeratorLastOwner();

	return TestFinish();
}

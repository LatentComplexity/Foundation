#import <Foundation/NSException.h>
#import "Test.h"

#import <objc/runtime.h>

static void
TestExceptionConstants(void)
{
	TEST_OBJ_EQ(NSGenericException, @"NSGenericException");
	TEST_OBJ_EQ(NSRangeException, @"NSRangeException");
	TEST_OBJ_EQ(NSUninitializedObjectUsageException, @"NSUninitializedObjectUsageException");
	TEST_OBJ_EQ(NSUnavailableMethodUsageException, @"NSUnavailableMethodUsageException");
	TEST_OBJ_EQ(NSInvalidArgumentException, @"NSInvalidArgumentException");
	TEST_OBJ_EQ(NSInternalInconsistencyException, @"NSInternalInconsistencyException");
	TEST_OBJ_EQ(NSMallocException, @"NSMallocException");
}

static void
TestCompleteException(void)
{
	@autoreleasepool {
		NSObject *userInfo = [NSObject new];
		NSException *exception = [NSException exceptionWithName:@"ConstructionException"
			reason:@"construction succeeded" userInfo:userInfo];
		id copy = [exception copy];

		TEST(exception != nil);
		TEST_STR_EQ(object_getClassName(exception), "NSException");
		TEST_OBJ_EQ(exception.name, @"ConstructionException");
		TEST_OBJ_EQ(exception.reason, @"construction succeeded");
		TEST(exception.userInfo == userInfo);
		TEST_OBJ_EQ(exception.description, @"construction succeeded");
		TEST(copy == exception);
	}
}

static void
TestOptionalArguments(void)
{
	@autoreleasepool {
		NSException *exception = [NSException exceptionWithName:@"BareException" reason:nil userInfo:nil];

		TEST(exception != nil);
		TEST_OBJ_EQ(exception.name, @"BareException");
		TEST(exception.reason == nil);
		TEST(exception.userInfo == nil);
		TEST_OBJ_EQ(exception.description, @"BareException");
	}
}

static void
TestDistinctInstances(void)
{
	@autoreleasepool {
		NSException *first = [NSException exceptionWithName:NSGenericException reason:@"reason" userInfo:nil];
		NSException *second = [NSException exceptionWithName:NSGenericException reason:@"reason" userInfo:nil];

		TEST(first != second);
	}
}

int
main(void)
{
	TestExceptionConstants();
	TestCompleteException();
	TestOptionalArguments();
	TestDistinctInstances();

	return TestFinish();
}

#import "Test.h"

int
main(void)
{
	@autoreleasepool {
		unsigned char const actualBytes[] = { 1, 2, 3, 4 };
		unsigned char const expectedBytes[] = { 1, 2, 3, 4 };
		NSObject *first = [NSObject new];
		NSObject *second = [NSObject new];
		int actual = 42;

		TEST(true);
		TEST_MSG(actual == 42, "a condition with context");
		TESTF(actual == 42, "actual was %d", actual);
		TESTF(true, "a formatted assertion with no arguments");
		TEST_EQ(actual, 42);
		TEST_NE(actual, 41);
		TEST_EQ_SIGNED(-42, -42);
		TEST_EQ_UNSIGNED((NSUInteger)42, 42);
		TEST_NEAR(0.1 + 0.2, 0.3, 0.0000001);
		TEST_OBJ_EQ(first, first);
		TEST_OBJ_NE(first, second);
		TEST_STR_EQ("Foundation", "Foundation");
		TEST_STR_EQ_MSG("Foundation", "Foundation", "identical output");
		TEST_BYTES_EQ(actualBytes, expectedBytes, sizeof(actualBytes));
		TEST_NO_THROW((void)0);
		TEST_THROWS([NSException raise:NSGenericException format:@"reason"]);
		TEST_THROWS_NAME(NSGenericException, [NSException raise:NSGenericException format:@"reason"]);
		TEST_THROWS_MATCHING(NSGenericException, @"reason",
			[NSException raise:NSGenericException format:@"reason"]);
	}

	return TestFinish();
}

#import <Foundation/NSException.h>
#import "Test.h"

static void
RaiseWithArguments(NSExceptionName name, NSString *format, ...) NS_FORMAT_FUNCTION(2, 3);

static void
RaiseWithArguments(NSExceptionName name, NSString *format, ...)
{
	__builtin_va_list arguments;

	__builtin_va_start(arguments, format);
	[NSException raise:name format:format arguments:arguments];
}

static void
TestDirectThrow(void)
{
	@autoreleasepool {
		NSException *exception = [NSException exceptionWithName:@"DirectException"
			reason:@"direct throw" userInfo:[NSObject new]];
		NSException *caught = nil;
		bool finallyRan = false;

		TestExpectedLeaksBegin();
		@try {
			@throw exception;
		} @catch (NSException *candidate) {
			caught = candidate;
		} @finally {
			finallyRan = true;
		}
		TestExpectedLeaksEnd();

		TEST(caught == exception);
		TEST(finallyRan);
	}
}

static void
TestRaiseMethod(void)
{
	@autoreleasepool {
		NSException *exception = [NSException exceptionWithName:@"RaisedException"
			reason:@"instance raise" userInfo:nil];
		NSException *caught = nil;

		TestExpectedLeaksBegin();
		@try {
			[exception raise];
		} @catch (NSException *candidate) {
			caught = candidate;
		}
		TestExpectedLeaksEnd();

		TEST(caught == exception);
	}
}

static void
TestFormattedRaise(void)
{
	@autoreleasepool {
		NSException *caught = nil;

		TestExpectedLeaksBegin();
		@try {
			[NSException raise:NSGenericException format:@"value %d: %@", 42, @"success"];
		} @catch (NSException *exception) {
			caught = exception;
		}
		TestExpectedLeaksEnd();

		TEST(caught != nil);
		TEST_OBJ_EQ(caught.name, NSGenericException);
		TEST_STR_EQ(caught.reason.UTF8String, "value 42: success");

		caught = nil;
		TestExpectedLeaksBegin();
		@try {
			RaiseWithArguments(NSRangeException, @"range %u + %u", 7U, 9U);
		} @catch (NSException *exception) {
			caught = exception;
		}
		TestExpectedLeaksEnd();

		TEST(caught != nil);
		TEST_OBJ_EQ(caught.name, NSRangeException);
		TEST_STR_EQ(caught.reason.UTF8String, "range 7 + 9");
	}
}

static void
TestRethrow(void)
{
	@autoreleasepool {
		NSException *exception = [NSException exceptionWithName:@"RethrownException"
			reason:nil userInfo:nil];
		NSException *caught = nil;

		TestExpectedLeaksBegin();
		@try {
			@try {
				@throw exception;
			} @catch (NSException *candidate) {
				TEST(candidate == exception);
				@throw;
			}
		} @catch (NSException *candidate) {
			caught = candidate;
		}
		TestExpectedLeaksEnd();

		TEST(caught == exception);
	}
}

int
main(void)
{
	TestDirectThrow();
	TestRaiseMethod();
	TestFormattedRaise();
	TestRethrow();

	return TestFinish();
}

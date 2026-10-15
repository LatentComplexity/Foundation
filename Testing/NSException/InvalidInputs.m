#import <Foundation/NSException.h>
#import "Test.h"

#import <objc/runtime.h>

static void
TestNilName(void)
{
	@autoreleasepool {
		NSExceptionName nilName = nil;
		NSException *caught = nil;

		TestExpectedLeaksBegin();
		@try {
			(void)[NSException exceptionWithName:nilName reason:@"reason" userInfo:[NSObject new]];
		} @catch (NSException *exception) {
			caught = exception;
		}
		TestExpectedLeaksEnd();

		TEST(caught != nil);
		TEST_OBJ_EQ(caught.name, NSInvalidArgumentException);
		TEST_STR_EQ(caught.reason.UTF8String,
			"+[NSException exceptionWithName:reason:userInfo:]: name was nil.");
	}
}

static void
TestUnavailableInitializer(void)
{
	@autoreleasepool {
		NSException *exception = class_createInstance([NSException class], 0);
		SEL initializer = sel_registerName("init");
		NSException *caught = nil;

		TestExpectedLeaksBegin();
		@try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-strict"
			(void)((id (*)(id, SEL))objc_msgSend)(exception, initializer);
#pragma clang diagnostic pop
		} @catch (NSException *raised) {
			caught = raised;
		}
		TestExpectedLeaksEnd();

		TEST(caught != nil);
		TEST_OBJ_EQ(caught.name, NSUnavailableMethodUsageException);
		TEST_STR_EQ(caught.reason.UTF8String, "-[NSException init]: unavailable method was invoked.");
	}
}

int
main(void)
{
	TestNilName();
	TestUnavailableInitializer();

	return TestFinish();
}

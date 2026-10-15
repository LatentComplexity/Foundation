#import <Foundation/NSException.h>
#import <Foundation/NSUUID.h>
#import "Test.h"

static void
TestMalformedStrings(void)
{
	@autoreleasepool {
		NSString *const malformed[] = {
			@"",
			@"919108F7-52D1-4320-9BAC-F847DB4148A",
			@"919108F7-52D1-4320-9BAC-F847DB4148A80",
			@"919108F752D1-4320-9BAC-F847-DB4148A8",
			@"919108F7_52D1-4320-9BAC-F847DB4148A8",
			@"919108F7-52D1_4320-9BAC-F847DB4148A8",
			@"919108F7-52D1-4320_9BAC-F847DB4148A8",
			@"919108F7-52D1-4320-9BAC_F847DB4148A8",
			@"G19108F7-52D1-4320-9BAC-F847DB4148A8",
			@"919108F7-52D1-4320-9BAC-F847DB4148AG",
			@"{19108F7-52D1-4320-9BAC-F847DB4148A8}",
			@"919108F7-52D1-4320-9BAC-F847DB4148\u00E9"
		};

		for (NSUInteger i = 0; i < sizeof(malformed) / sizeof(malformed[0]); ++i)
			TEST([NSUUID UUIDWithUUIDString:malformed[i]] == nil);
	}
}

static void
TestNilAndNullArguments(void)
{
	@autoreleasepool {
		NSUUID *uuid = [NSUUID UUIDWithUUIDBytes:(UUID_t)0];
		NSUUID *nilUUID = nil;
		NSString *nilString = nil;
		UUID_t *nullBytes = nullptr;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[NSUUID UUIDWithUUIDString:nilString]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [uuid getUUIDBytes:nullBytes]);
		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[uuid isEqualToUUID:nilUUID]);
		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[uuid compare:nilUUID]);
#pragma clang diagnostic pop
	}
}

static void
TestUnavailableInitialization(void)
{
	@autoreleasepool {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-messaging-id"
		TEST_THROWS_NAME(NSUnavailableMethodUsageException, (void)[(id)[NSUUID alloc] init]);
		TEST_THROWS_NAME(NSUnavailableMethodUsageException,
			(void)[(id)[NSUUID UUIDWithUUIDBytes:(UUID_t)0] init]);
#pragma clang diagnostic pop
	}
}

int
main(void)
{
	TestMalformedStrings();
	TestNilAndNullArguments();
	TestUnavailableInitialization();

	return TestFinish();
}

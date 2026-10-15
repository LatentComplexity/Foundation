#import <Foundation/NSUUID.h>
#import "Test.h"

static UUID_t
UUIDValue(unsigned long long const high, unsigned long long const low)
{
	return (UUID_t)high << 64 | (UUID_t)low;
}

static void
TestCopyEqualityAndHashing(void)
{
	@autoreleasepool {
		UUID_t const bytes = UUIDValue(0x919108F752D14320ULL, 0x9BACF847DB4148A8ULL);
		NSUUID *first = [NSUUID UUIDWithUUIDBytes:bytes];
		NSUUID *same = [NSUUID UUIDWithUUIDString:@"919108f7-52d1-4320-9bac-f847db4148a8"];
		NSUUID *different = [NSUUID UUIDWithUUIDBytes:bytes + 1];
		NSUUID *copy = [first copy];
		NSUInteger const hash = first.hash;

		TEST(copy == first);
		TEST([first isEqualToUUID:first]);
		TEST([first isEqualToUUID:same]);
		TEST([same isEqualToUUID:first]);
		TEST([first isEqual:same]);
		TEST([same isEqual:first]);
		TEST_EQ_UNSIGNED(hash, first.hash);
		TEST_EQ_UNSIGNED(hash, first.hash);
		TEST_EQ_UNSIGNED(hash, same.hash);
		NSLog(@"first.description.UTF8String is: %s", first.description.UTF8String);
		TEST_STR_EQ(first.description.UTF8String, "919108F7-52D1-4320-9BAC-F847DB4148A8");

		TEST([first isEqualToUUID:different] == false);
		TEST([first isEqual:different] == false);
		TEST([first isEqual:first.UUIDString] == false);
		TEST([first isEqual:nil] == false);
	}
}

static void
TestComparison(void)
{
	@autoreleasepool {
		NSUUID *low = [NSUUID UUIDWithUUIDBytes:(UUID_t)0];
		NSUUID *middle = [NSUUID UUIDWithUUIDBytes:(UUID_t)1 << 64];
		NSUUID *high = [NSUUID UUIDWithUUIDBytes:~(UUID_t)0];

		TEST_EQ([low compare:low], NSOrderedSame);
		TEST_EQ([low compare:middle], NSOrderedAscending);
		TEST_EQ([middle compare:low], NSOrderedDescending);
		TEST_EQ([middle compare:high], NSOrderedAscending);
		TEST_EQ([high compare:middle], NSOrderedDescending);
	}
}

int
main(void)
{
	TestCopyEqualityAndHashing();
	TestComparison();

	return TestFinish();
}

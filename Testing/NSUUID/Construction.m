#import <Foundation/NSUUID.h>
#import "Test.h"

static UUID_t
UUIDValue(unsigned long long const high, unsigned long long const low)
{
	return (UUID_t)high << 64 | (UUID_t)low;
}

static void
TestStringConstruction(void)
{
	@autoreleasepool {
		struct {
			NSString *input;
			char const *output;
			UUID_t bytes;
		} const fixtures[] = {
			{
				@"f81d4fae-7dec-11d0-a765-00a0c91e6bf6",
				"F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6",
				UUIDValue(0xF81D4FAE7DEC11D0ULL, 0xA76500A0C91E6BF6ULL)
			},
			{
				@"919108f7-52D1-4320-9bAc-f847db4148a8",
				"919108F7-52D1-4320-9BAC-F847DB4148A8",
				UUIDValue(0x919108F752D14320ULL, 0x9BACF847DB4148A8ULL)
			},
			{
				@"00000000-0000-0000-0000-000000000000",
				"00000000-0000-0000-0000-000000000000",
				(UUID_t)0
			},
			{
				@"FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",
				"FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",
				~(UUID_t)0
			},
			{
				@"01890f3e-8b72-7cc6-98c4-dc0c0c07398f",
				"01890F3E-8B72-7CC6-98C4-DC0C0C07398F",
				UUIDValue(0x01890F3E8B727CC6ULL, 0x98C4DC0C0C07398FULL)
			}
		};

		for (NSUInteger i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
			NSUUID *uuid = [NSUUID UUIDWithUUIDString:fixtures[i].input];
			UUID_t bytes = 0;

			TEST(uuid != nil);
			if (uuid == nil)
				continue;

			TEST_STR_EQ(uuid.UUIDString.UTF8String, fixtures[i].output);
			[uuid getUUIDBytes:&bytes];
			TEST(bytes == fixtures[i].bytes);
		}
	}
}

static void
TestByteConstruction(void)
{
	@autoreleasepool {
		UUID_t const fixtures[] = {
			(UUID_t)0,
			~(UUID_t)0,
			UUIDValue(0xF81D4FAE7DEC11D0ULL, 0xA76500A0C91E6BF6ULL),
			UUIDValue(0x919108F752D14320ULL, 0x9BACF847DB4148A8ULL)
		};

		for (NSUInteger i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
			NSUUID *uuid = [NSUUID UUIDWithUUIDBytes:fixtures[i]];
			UUID_t bytes = ~fixtures[i];

			TEST(uuid != nil);
			[uuid getUUIDBytes:&bytes];
			TEST(bytes == fixtures[i]);
		}
	}
}

static void
TestRandomConstruction(void)
{
	@autoreleasepool {
		NSUUID *previous = nil;

		for (unsigned i = 0; i < 128; ++i) {
			NSUUID *uuid = [NSUUID UUID];
			UUID_t bytes = 0;
			NSUUID *roundTrip;

			TEST(uuid != nil);
			[uuid getUUIDBytes:&bytes];
			TEST(((bytes >> 76) & (UUID_t)0xF) == (UUID_t)4);
			TEST(((bytes >> 62) & (UUID_t)0x3) == (UUID_t)0b10);
			TEST(previous == nil || [uuid isEqualToUUID:previous] == false);

			roundTrip = [NSUUID UUIDWithUUIDString:uuid.UUIDString];
			TEST(roundTrip != nil && [uuid isEqualToUUID:roundTrip]);
			previous = uuid;
		}
	}
}

int
main(void)
{
	TestStringConstruction();
	TestByteConstruction();
	TestRandomConstruction();

	return TestFinish();
}

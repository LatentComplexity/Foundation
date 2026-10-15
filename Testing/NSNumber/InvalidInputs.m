#import "Corpus.h"
#import "Test.h"

static NSUInteger
StoredSize(NSNumberFixtureSource source)
{
	switch (source) {
	case NSNumberFixtureSourceChar:
		return sizeof(char);
	case NSNumberFixtureSourceUnsignedChar:
		return sizeof(unsigned char);
	case NSNumberFixtureSourceShort:
		return sizeof(short);
	case NSNumberFixtureSourceUnsignedShort:
		return sizeof(unsigned short);
	case NSNumberFixtureSourceInt:
		return sizeof(int);
	case NSNumberFixtureSourceUnsignedInt:
		return sizeof(unsigned int);
	case NSNumberFixtureSourceLong:
		return sizeof(long);
	case NSNumberFixtureSourceUnsignedLong:
		return sizeof(unsigned long);
	case NSNumberFixtureSourceLongLong:
		return sizeof(long long);
	case NSNumberFixtureSourceUnsignedLongLong:
		return sizeof(unsigned long long);
	case NSNumberFixtureSourceInteger:
		return sizeof(NSInteger);
	case NSNumberFixtureSourceUnsignedInteger:
		return sizeof(NSUInteger);
	case NSNumberFixtureSourceBool:
		return sizeof(bool);
	case NSNumberFixtureSourceFloat:
		return sizeof(float);
	case NSNumberFixtureSourceDouble:
		return sizeof(double);
	}
}

static void
TestReinitialization(NSNumber *number, NSString *className)
{
	NSString *reason = [NSString stringWithFormat:
		@"-[%@ initWithInt:]: reinitialization of initialized object was attempted.", className];

	TEST_THROWS_MATCHING(NSUnavailableMethodUsageException, reason, (void)[number initWithInt:0]);
}

int
main(void)
{
	@autoreleasepool {
		NSNumberFixture fixtures[NSNumberFixtureMaximumCount] = {};
		size_t const count = NSNumberBuildFixtureCorpus(fixtures);
		unsigned char storage[sizeof(double)] = { 0 };
		NSNumber *compareNumbers[] = {
			[NSNumber numberWithInt:0],
			[NSNumber numberWithFloat:0.5f],
			[NSNumber numberWithLong:-9007199254740993L],
			[NSNumber numberWithLong:9007199254740993L],
			[NSNumber numberWithDouble:0x1p51 + 0.5],
			[NSNumber numberWithFloat:__builtin_nanf("")],
			[NSNumber numberWithDouble:__builtin_nan("")],
			[NSNumber numberWithFloat:-__builtin_inff()],
			[NSNumber numberWithFloat:__builtin_inff()],
			[NSNumber numberWithDouble:-__builtin_inf()],
			[NSNumber numberWithDouble:__builtin_inf()]
		};
		int const value = 1;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSNumber alloc] initWithBytes:nullptr objCType:@encode(int)]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSNumber alloc] initWithBytes:&value objCType:nullptr]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [fixtures[0].number isEqualToNumber:nil]);
		for (size_t i = 0; i < sizeof(compareNumbers) / sizeof(compareNumbers[0]); ++i)
			TEST_THROWS_NAME(NSInvalidArgumentException, [compareNumbers[i] compare:nil]);
#pragma clang diagnostic pop
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSNumber alloc] initWithBytes:&value objCType:""]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSNumber alloc] initWithBytes:&value objCType:"ii"]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSNumber alloc] initWithBytes:&value objCType:@encode(void)]);

		for (size_t i = 0; i < count; ++i) {
			NSUInteger const size = StoredSize(fixtures[i].source);
			NSUInteger const wrongSize = size == sizeof(storage) ? size - 1 : size + 1;
			TEST_THROWS_NAME(NSInvalidArgumentException,
				[fixtures[i].number getValue:storage size:wrongSize]);
		}

		TestReinitialization([NSNumber numberWithInt:0], @"NSTaggedIntegerNumber");
		TestReinitialization([NSNumber numberWithFloat:0.5f], @"NSTaggedFloatNumber");
		TestReinitialization([NSNumber numberWithLong:-9007199254740993L], @"NSNegativeIntegerNumber");
		TestReinitialization([NSNumber numberWithLong:9007199254740993L], @"NSPositiveIntegerNumber");
		TestReinitialization([NSNumber numberWithDouble:0x1p51 + 0.5], @"NSDoubleNumber");
		TestReinitialization([NSNumber numberWithFloat:__builtin_nanf("")], @"NSNaNFloatNumber");
		TestReinitialization([NSNumber numberWithDouble:__builtin_nan("")], @"NSNaNDoubleNumber");
		TestReinitialization([NSNumber numberWithFloat:-__builtin_inff()],
			@"NSNegativeInfinityFloatNumber");
		TestReinitialization([NSNumber numberWithFloat:__builtin_inff()],
			@"NSPositiveInfinityFloatNumber");
		TestReinitialization([NSNumber numberWithDouble:-__builtin_inf()],
			@"NSNegativeInfinityDoubleNumber");
		TestReinitialization([NSNumber numberWithDouble:__builtin_inf()],
			@"NSPositiveInfinityDoubleNumber");
	}

	return TestFinish();
}

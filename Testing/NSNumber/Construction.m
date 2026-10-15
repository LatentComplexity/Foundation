#import <Foundation/NSValue.h>
#import "Test.h"

#import <objc/runtime.h>

#include <float.h>
#include <string.h>

static void
TestInitializer(NSNumber *number, NSNumber *factoryNumber)
{
	TEST(number != nil);
	TEST(object_getClass(number) == object_getClass(factoryNumber));
	TEST_STR_EQ(number.objCType, factoryNumber.objCType);
	TEST([number isEqualToNumber:factoryNumber]);
}

static void
TestByteInitializer(void)
{
	char const c = (char)-1;
	unsigned char const C = 255;
	short const s = -32768;
	unsigned short const S = 65535;
	int const i = -2147483647 - 1;
	unsigned int const I = 4294967295U;
	long const l = -9007199254740993L;
	unsigned long const L = 9007199254740993UL;
	long long const q = -9007199254740993LL;
	unsigned long long const Q = 9007199254740993ULL;
	bool const B = true;
	float const f = 1.5f;
	double const d = 0x1p51 + 0.5;

	TestInitializer([[NSNumber alloc] initWithBytes:&c objCType:@encode(char)],
		[NSNumber numberWithChar:c]);
	TestInitializer([[NSNumber alloc] initWithBytes:&C objCType:@encode(unsigned char)],
		[NSNumber numberWithUnsignedChar:C]);
	TestInitializer([[NSNumber alloc] initWithBytes:&s objCType:@encode(short)],
		[NSNumber numberWithShort:s]);
	TestInitializer([[NSNumber alloc] initWithBytes:&S objCType:@encode(unsigned short)],
		[NSNumber numberWithUnsignedShort:S]);
	TestInitializer([[NSNumber alloc] initWithBytes:&i objCType:@encode(int)],
		[NSNumber numberWithInt:i]);
	TestInitializer([[NSNumber alloc] initWithBytes:&I objCType:@encode(unsigned int)],
		[NSNumber numberWithUnsignedInt:I]);
	TestInitializer([[NSNumber alloc] initWithBytes:&l objCType:@encode(long)],
		[NSNumber numberWithLong:l]);
	TestInitializer([[NSNumber alloc] initWithBytes:&L objCType:@encode(unsigned long)],
		[NSNumber numberWithUnsignedLong:L]);
	TestInitializer([[NSNumber alloc] initWithBytes:&q objCType:@encode(long long)],
		[NSNumber numberWithLongLong:q]);
	TestInitializer([[NSNumber alloc] initWithBytes:&Q objCType:@encode(unsigned long long)],
		[NSNumber numberWithUnsignedLongLong:Q]);
	TestInitializer([[NSNumber alloc] initWithBytes:&B objCType:@encode(bool)],
		[NSNumber numberWithBool:B]);
	TestInitializer([[NSNumber alloc] initWithBytes:&f objCType:@encode(float)],
		[NSNumber numberWithFloat:f]);
	TestInitializer([[NSNumber alloc] initWithBytes:&d objCType:@encode(double)],
		[NSNumber numberWithDouble:d]);
	TestInitializer((NSNumber *)[NSNumber valueWithBytes:&i objCType:@encode(int)],
		[NSNumber numberWithInt:i]);
}

int
main(void)
{
	@autoreleasepool {
		TestByteInitializer();

		TestInitializer([[NSNumber alloc] initWithChar:(char)-1], [NSNumber numberWithChar:(char)-1]);
		TestInitializer([[NSNumber alloc] initWithUnsignedChar:255],
			[NSNumber numberWithUnsignedChar:255]);
		TestInitializer([[NSNumber alloc] initWithShort:-32768], [NSNumber numberWithShort:-32768]);
		TestInitializer([[NSNumber alloc] initWithUnsignedShort:65535],
			[NSNumber numberWithUnsignedShort:65535]);
		TestInitializer([[NSNumber alloc] initWithInt:-2147483647 - 1],
			[NSNumber numberWithInt:-2147483647 - 1]);
		TestInitializer([[NSNumber alloc] initWithUnsignedInt:4294967295U],
			[NSNumber numberWithUnsignedInt:4294967295U]);

		TestInitializer([[NSNumber alloc] initWithLong:17], [NSNumber numberWithLong:17]);
		TestInitializer([[NSNumber alloc] initWithLong:-9007199254740993L],
			[NSNumber numberWithLong:-9007199254740993L]);
		TestInitializer([[NSNumber alloc] initWithLong:9007199254740993L],
			[NSNumber numberWithLong:9007199254740993L]);
		TestInitializer([[NSNumber alloc] initWithUnsignedLong:17],
			[NSNumber numberWithUnsignedLong:17]);
		TestInitializer([[NSNumber alloc] initWithUnsignedLong:9007199254740993UL],
			[NSNumber numberWithUnsignedLong:9007199254740993UL]);

		TestInitializer([[NSNumber alloc] initWithLongLong:17], [NSNumber numberWithLongLong:17]);
		TestInitializer([[NSNumber alloc] initWithLongLong:-9007199254740993LL],
			[NSNumber numberWithLongLong:-9007199254740993LL]);
		TestInitializer([[NSNumber alloc] initWithLongLong:9007199254740993LL],
			[NSNumber numberWithLongLong:9007199254740993LL]);
		TestInitializer([[NSNumber alloc] initWithUnsignedLongLong:17],
			[NSNumber numberWithUnsignedLongLong:17]);
		TestInitializer([[NSNumber alloc] initWithUnsignedLongLong:9007199254740993ULL],
			[NSNumber numberWithUnsignedLongLong:9007199254740993ULL]);

		TestInitializer([[NSNumber alloc] initWithInteger:-9007199254740993L],
			[NSNumber numberWithInteger:-9007199254740993L]);
		TestInitializer([[NSNumber alloc] initWithInteger:9007199254740993L],
			[NSNumber numberWithInteger:9007199254740993L]);
		TestInitializer([[NSNumber alloc] initWithUnsignedInteger:9007199254740993UL],
			[NSNumber numberWithUnsignedInteger:9007199254740993UL]);

		NSNumber *falseNumber = [[NSNumber alloc] initWithBool:false];
		NSNumber *trueNumber = [[NSNumber alloc] initWithBool:true];
		TestInitializer(falseNumber, [NSNumber numberWithBool:false]);
		TestInitializer(trueNumber, [NSNumber numberWithBool:true]);
		TEST(falseNumber == [NSNumber numberWithBool:false]);
		TEST(trueNumber == [NSNumber numberWithBool:true]);

		TestInitializer([[NSNumber alloc] initWithFloat:-0.0f], [NSNumber numberWithFloat:-0.0f]);
		TestInitializer([[NSNumber alloc] initWithFloat:1.5f], [NSNumber numberWithFloat:1.5f]);
		TestInitializer([[NSNumber alloc] initWithFloat:-0x1p54f], [NSNumber numberWithFloat:-0x1p54f]);
		TestInitializer([[NSNumber alloc] initWithFloat:0x1p54f], [NSNumber numberWithFloat:0x1p54f]);
		TestInitializer([[NSNumber alloc] initWithFloat:FLT_MAX], [NSNumber numberWithFloat:FLT_MAX]);
		TestInitializer([[NSNumber alloc] initWithFloat:__builtin_nanf("")],
			[NSNumber numberWithFloat:__builtin_nanf("")]);
		TestInitializer([[NSNumber alloc] initWithFloat:-__builtin_inff()],
			[NSNumber numberWithFloat:-__builtin_inff()]);
		TestInitializer([[NSNumber alloc] initWithFloat:__builtin_inff()],
			[NSNumber numberWithFloat:__builtin_inff()]);

		TestInitializer([[NSNumber alloc] initWithDouble:-0.0], [NSNumber numberWithDouble:-0.0]);
		TestInitializer([[NSNumber alloc] initWithDouble:1.5], [NSNumber numberWithDouble:1.5]);
		TestInitializer([[NSNumber alloc] initWithDouble:-0x1p54], [NSNumber numberWithDouble:-0x1p54]);
		TestInitializer([[NSNumber alloc] initWithDouble:0x1p54], [NSNumber numberWithDouble:0x1p54]);
		TestInitializer([[NSNumber alloc] initWithDouble:0x1p51 + 0.5],
			[NSNumber numberWithDouble:0x1p51 + 0.5]);
		TestInitializer([[NSNumber alloc] initWithDouble:DBL_MAX], [NSNumber numberWithDouble:DBL_MAX]);
		TestInitializer([[NSNumber alloc] initWithDouble:__builtin_nan("")],
			[NSNumber numberWithDouble:__builtin_nan("")]);
		TestInitializer([[NSNumber alloc] initWithDouble:-__builtin_inf()],
			[NSNumber numberWithDouble:-__builtin_inf()]);
		TestInitializer([[NSNumber alloc] initWithDouble:__builtin_inf()],
			[NSNumber numberWithDouble:__builtin_inf()]);
	}

	return TestFinish();
}

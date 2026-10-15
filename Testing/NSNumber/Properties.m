#import "Corpus.h"
#import "Test.h"

#include <inttypes.h>
#include <stdint.h>

@interface NSNumberForeignFloat : NSNumber

+ (instancetype)numberWithValue:(float)value;

@end

@implementation NSNumberForeignFloat {
	float _value;
}

+ (instancetype)numberWithValue:(float)value
{
	NSNumberForeignFloat *number = [self alloc];
	number->_value = value;
	return number;
}

- (char const *)objCType
{
	return @encode(float);
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	if (size != sizeof(_value))
		abort();

	__builtin_memcpy_inline(value, &_value, sizeof(_value));
}

@end

@interface NSNumberForeignDouble : NSNumber

+ (instancetype)numberWithValue:(double)value;

@end

@implementation NSNumberForeignDouble {
	double _value;
}

+ (instancetype)numberWithValue:(double)value
{
	NSNumberForeignDouble *number = [self alloc];
	number->_value = value;
	return number;
}

- (char const *)objCType
{
	return @encode(double);
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	if (size != sizeof(_value))
		abort();

	__builtin_memcpy_inline(value, &_value, sizeof(_value));
}

@end

static void
TestStoredValue(NSNumberFixture const *fixture, size_t index)
{
	NSNumber *number = fixture->number;
	char const *source = NSNumberFixtureSourceName(fixture->source);

	switch (fixture->source) {
	case NSNumberFixtureSourceChar: {
		char actual = 0;
		char const expected = (char)fixture->value.v.signedValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %d, expected %d", index, source,
			(int)actual, (int)expected);
		break;
	}
	case NSNumberFixtureSourceUnsignedChar: {
		unsigned char actual = 0;
		unsigned char const expected = (unsigned char)fixture->value.v.unsignedValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %u, expected %u", index, source,
			(unsigned)actual, (unsigned)expected);
		break;
	}
	case NSNumberFixtureSourceShort: {
		short actual = 0;
		short const expected = (short)fixture->value.v.signedValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %d, expected %d", index, source,
			(int)actual, (int)expected);
		break;
	}
	case NSNumberFixtureSourceUnsignedShort: {
		unsigned short actual = 0;
		unsigned short const expected = (unsigned short)fixture->value.v.unsignedValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %u, expected %u", index, source,
			(unsigned)actual, (unsigned)expected);
		break;
	}
	case NSNumberFixtureSourceInt: {
		int actual = 0;
		int const expected = (int)fixture->value.v.signedValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %d, expected %d", index, source, actual, expected);
		break;
	}
	case NSNumberFixtureSourceUnsignedInt: {
		unsigned int actual = 0;
		unsigned int const expected = (unsigned int)fixture->value.v.unsignedValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %u, expected %u", index, source, actual, expected);
		break;
	}
	case NSNumberFixtureSourceLong:
	case NSNumberFixtureSourceInteger: {
		long actual = 0;
		long const expected = (long)fixture->value.v.signedValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %jd, expected %jd", index, source,
			(intmax_t)actual, (intmax_t)expected);
		break;
	}
	case NSNumberFixtureSourceUnsignedLong:
	case NSNumberFixtureSourceUnsignedInteger: {
		unsigned long actual = 0;
		unsigned long const expected = (unsigned long)fixture->value.v.unsignedValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %ju, expected %ju", index, source,
			(uintmax_t)actual, (uintmax_t)expected);
		break;
	}
	case NSNumberFixtureSourceLongLong: {
		long long actual = 0;
		long long const expected = (long long)fixture->value.v.signedValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %jd, expected %jd", index, source,
			(intmax_t)actual, (intmax_t)expected);
		break;
	}
	case NSNumberFixtureSourceUnsignedLongLong: {
		unsigned long long actual = 0;
		unsigned long long const expected = (unsigned long long)fixture->value.v.unsignedValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %ju, expected %ju", index, source,
			(uintmax_t)actual, (uintmax_t)expected);
		break;
	}
	case NSNumberFixtureSourceBool: {
		bool actual = false;
		bool const expected = fixture->value.v.unsignedValue != 0;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(actual == expected, "%zu/%s getValue: got %d, expected %d", index, source,
			(int)actual, (int)expected);
		break;
	}
	case NSNumberFixtureSourceFloat: {
		float actual = 0.0f;
		float const expected = (float)fixture->value.v.floatingValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(NSNumberFixtureFloatMatches(actual, expected),
			"%zu/%s getValue: got %a, expected %a", index, source, (double)actual, (double)expected);
		break;
	}
	case NSNumberFixtureSourceDouble: {
		double actual = 0.0;
		double const expected = fixture->value.v.floatingValue;
		[number getValue:&actual size:sizeof(actual)];
		TESTF(NSNumberFixtureDoubleMatches(actual, expected),
			"%zu/%s getValue: got %a, expected %a", index, source, actual, expected);
		break;
	}
	}
}

static void
TestPropertyGetters(NSNumberFixture const *fixture, size_t index)
{
	NSNumber *number = fixture->number;
	NSNumberFixtureValue const value = fixture->value;
	char const *source = NSNumberFixtureSourceName(fixture->source);
	int64_t signedExpected;
	uint64_t unsignedExpected;
	int64_t signedActual;
	uint64_t unsignedActual;
	float floatActual;
	float floatExpected;
	double doubleActual;
	double doubleExpected;
	bool boolActual;
	bool boolExpected;

#define TestSignedGetter(getter, Type, Bits) \
	signedExpected = NSNumberFixtureExpectedSigned(value, Bits); \
	signedActual = (int64_t)(Type)number.getter; \
	TESTF(signedActual == signedExpected, "%zu/%s input=%a %s: got %jd, expected %jd", index, source, \
		NSNumberFixtureExpectedDouble(value), #getter, (intmax_t)signedActual, (intmax_t)signedExpected)

#define TestUnsignedGetter(getter, Type, Bits) \
	unsignedExpected = NSNumberFixtureExpectedUnsigned(value, Bits); \
	unsignedActual = (uint64_t)(Type)number.getter; \
	TESTF(unsignedActual == unsignedExpected, "%zu/%s input=%a %s: got %ju, expected %ju", index, source, \
		NSNumberFixtureExpectedDouble(value), #getter, (uintmax_t)unsignedActual, (uintmax_t)unsignedExpected)

#if defined(__CHAR_UNSIGNED__)
	TestUnsignedGetter(charValue, char, 8);
#else
	TestSignedGetter(charValue, char, 8);
#endif
	TestUnsignedGetter(unsignedCharValue, unsigned char, 8);
	TestSignedGetter(shortValue, short, 16);
	TestUnsignedGetter(unsignedShortValue, unsigned short, 16);
	TestSignedGetter(intValue, int, 32);
	TestUnsignedGetter(unsignedIntValue, unsigned int, 32);
	TestSignedGetter(longValue, long, 64);
	TestUnsignedGetter(unsignedLongValue, unsigned long, 64);
	TestSignedGetter(longLongValue, long long, 64);
	TestUnsignedGetter(unsignedLongLongValue, unsigned long long, 64);
	TestSignedGetter(integerValue, NSInteger, 64);
	TestUnsignedGetter(unsignedIntegerValue, NSUInteger, 64);

#undef TestSignedGetter
#undef TestUnsignedGetter

	boolActual = number.boolValue;
	boolExpected = NSNumberFixtureExpectedBool(value);
	TESTF(boolActual == boolExpected, "%zu/%s boolValue: got %d, expected %d", index, source,
		(int)boolActual, (int)boolExpected);

	floatActual = number.floatValue;
	floatExpected = NSNumberFixtureExpectedFloat(value);
	TESTF(NSNumberFixtureFloatMatches(floatActual, floatExpected),
		"%zu/%s floatValue: got %a, expected %a", index, source,
		(double)floatActual, (double)floatExpected);

	doubleActual = number.doubleValue;
	doubleExpected = NSNumberFixtureExpectedDouble(value);
	TESTF(NSNumberFixtureDoubleMatches(doubleActual, doubleExpected),
		"%zu/%s doubleValue: got %a, expected %a", index, source, doubleActual, doubleExpected);
}

static void
TestTypeAndPointer(NSNumberFixture const *fixture, size_t index)
{
	NSNumber *number = fixture->number;
	char const *source = NSNumberFixtureSourceName(fixture->source);
	char const *type = number.objCType;
	bool const pointerSized = fixture->expectedObjCType == 'l' || fixture->expectedObjCType == 'L' ||
		fixture->expectedObjCType == 'q' || fixture->expectedObjCType == 'Q';
	uintptr_t const actualPointer = (uintptr_t)number.pointerValue;
	uintptr_t const expectedPointer = pointerSized ?
		(uintptr_t)NSNumberFixtureExpectedUnsigned(fixture->value, 64) : 0;

	TESTF(type != nullptr, "%zu/%s objCType is null", index, source);
	if (type != nullptr) {
		TESTF(type[0] == fixture->expectedObjCType, "%zu/%s objCType: got '%c', expected '%c'", index,
			source, type[0], fixture->expectedObjCType);
		TESTF(type[1] == '\0', "%zu/%s objCType has a non-empty suffix", index, source);
	}
	TESTF(actualPointer == expectedPointer, "%zu/%s pointerValue: got 0x%jx, expected 0x%jx", index,
		source, (uintmax_t)actualPointer, (uintmax_t)expectedPointer);
}

int
main(void)
{
	@autoreleasepool {
		NSNumberFixture fixtures[NSNumberFixtureMaximumCount] = {};
		size_t const count = NSNumberBuildFixtureCorpus(fixtures);

		TESTF(count > 300, "corpus unexpectedly contains only %zu fixtures", count);
		for (size_t i = 0; i < count; ++i) {
			TestStoredValue(&fixtures[i], i);
			TestPropertyGetters(&fixtures[i], i);
			TestTypeAndPointer(&fixtures[i], i);
		}

		for (size_t i = 0; i < count; ++i) {
			NSNumberFixture foreignFixture = fixtures[i];

			if (foreignFixture.source == NSNumberFixtureSourceFloat)
				foreignFixture.number =
					[NSNumberForeignFloat numberWithValue:(float)foreignFixture.value.v.floatingValue];
			else if (foreignFixture.source == NSNumberFixtureSourceDouble)
				foreignFixture.number =
					[NSNumberForeignDouble numberWithValue:foreignFixture.value.v.floatingValue];
			else
				continue;

			TestStoredValue(&foreignFixture, i);
			TestPropertyGetters(&foreignFixture, i);
			TestTypeAndPointer(&foreignFixture, i);
		}
	}

	return TestFinish();
}

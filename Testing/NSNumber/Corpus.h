#ifndef FOUNDATION_TEST_NSNUMBER_CORPUS_H
#define FOUNDATION_TEST_NSNUMBER_CORPUS_H

#import <Foundation/NSValue.h>

#include <float.h>
#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/*
 * This corpus is shared by the maintained tests and the Apple-Foundation oracle.  The source type is retained
 * separately from the mathematical value because NSInteger/NSUInteger alias long/unsigned long on LP64, while
 * still representing distinct public construction paths that must be exercised.
 */

typedef enum NSNumberFixtureSource {
	NSNumberFixtureSourceChar,
	NSNumberFixtureSourceUnsignedChar,
	NSNumberFixtureSourceShort,
	NSNumberFixtureSourceUnsignedShort,
	NSNumberFixtureSourceInt,
	NSNumberFixtureSourceUnsignedInt,
	NSNumberFixtureSourceLong,
	NSNumberFixtureSourceUnsignedLong,
	NSNumberFixtureSourceLongLong,
	NSNumberFixtureSourceUnsignedLongLong,
	NSNumberFixtureSourceInteger,
	NSNumberFixtureSourceUnsignedInteger,
	NSNumberFixtureSourceBool,
	NSNumberFixtureSourceFloat,
	NSNumberFixtureSourceDouble
} NSNumberFixtureSource;

typedef enum NSNumberFixtureDomain {
	NSNumberFixtureDomainSigned,
	NSNumberFixtureDomainUnsigned,
	NSNumberFixtureDomainFloating
} NSNumberFixtureDomain;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpadded"

typedef struct NSNumberFixtureValue {
	NSNumberFixtureDomain domain;
	union {
		int64_t signedValue;
		uint64_t unsignedValue;
		double floatingValue;
	} v;
} NSNumberFixtureValue;

typedef struct NSNumberFixture {
	NSNumberFixtureValue value;
	__strong NSNumber *number;
	NSNumberFixtureSource source;
	char expectedObjCType;
} NSNumberFixture;

#pragma clang diagnostic pop

enum {
	NSNumberFixtureMaximumCount = 512
};

static inline char const *
NSNumberFixtureSourceName(NSNumberFixtureSource source)
{
	switch (source) {
	case NSNumberFixtureSourceChar:
		return "char";
	case NSNumberFixtureSourceUnsignedChar:
		return "unsigned char";
	case NSNumberFixtureSourceShort:
		return "short";
	case NSNumberFixtureSourceUnsignedShort:
		return "unsigned short";
	case NSNumberFixtureSourceInt:
		return "int";
	case NSNumberFixtureSourceUnsignedInt:
		return "unsigned int";
	case NSNumberFixtureSourceLong:
		return "long";
	case NSNumberFixtureSourceUnsignedLong:
		return "unsigned long";
	case NSNumberFixtureSourceLongLong:
		return "long long";
	case NSNumberFixtureSourceUnsignedLongLong:
		return "unsigned long long";
	case NSNumberFixtureSourceInteger:
		return "NSInteger";
	case NSNumberFixtureSourceUnsignedInteger:
		return "NSUInteger";
	case NSNumberFixtureSourceBool:
		return "bool";
	case NSNumberFixtureSourceFloat:
		return "float";
	case NSNumberFixtureSourceDouble:
		return "double";
	}
}

static inline void
NSNumberFixtureAddSigned(NSNumberFixture *fixtures, size_t *count, NSNumberFixtureSource source,
	char expectedObjCType, int64_t value, NSNumber *number)
{
	if (*count == NSNumberFixtureMaximumCount)
		abort();

	fixtures[*count] = (NSNumberFixture){
		.source = source,
		.value = {
			.domain = NSNumberFixtureDomainSigned,
			.v.signedValue = value
		},
		.expectedObjCType = expectedObjCType,
		.number = number
	};
	++*count;
}

static inline void
NSNumberFixtureAddUnsigned(NSNumberFixture *fixtures, size_t *count, NSNumberFixtureSource source,
	char expectedObjCType, uint64_t value, NSNumber *number)
{
	if (*count == NSNumberFixtureMaximumCount)
		abort();

	fixtures[*count] = (NSNumberFixture){
		.source = source,
		.value = {
			.domain = NSNumberFixtureDomainUnsigned,
			.v.unsignedValue = value
		},
		.expectedObjCType = expectedObjCType,
		.number = number
	};
	++*count;
}

static inline void
NSNumberFixtureAddFloating(NSNumberFixture *fixtures, size_t *count, NSNumberFixtureSource source,
	char expectedObjCType, double value, NSNumber *number)
{
	if (*count == NSNumberFixtureMaximumCount)
		abort();

	fixtures[*count] = (NSNumberFixture){
		.source = source,
		.value = {
			.domain = NSNumberFixtureDomainFloating,
			.v.floatingValue = value
		},
		.expectedObjCType = expectedObjCType,
		.number = number
	};
	++*count;
}

static inline size_t
NSNumberBuildFixtureCorpus(NSNumberFixture *fixtures)
{
#if defined(__CHAR_UNSIGNED__)
	static char const charValues[] = {
		0, 1, 127, (char)128U, (char)254U, (char)255U
	};
#else
	static char const charValues[] = {
		CHAR_MIN, (char)(CHAR_MIN + 1), (char)-1, 0, 1, (char)(CHAR_MAX - 1), CHAR_MAX
	};
#endif
	static unsigned char const unsignedCharValues[] = {
		0U, 1U, 127U, 128U, 254U, 255U
	};
	static short const shortValues[] = {
		SHRT_MIN, (short)(SHRT_MIN + 1), -129, -128, -1, 0, 1, 127, 128,
		(short)(SHRT_MAX - 1), SHRT_MAX
	};
	static unsigned short const unsignedShortValues[] = {
		0U, 1U, 127U, 128U, 255U, 256U, 32767U, 32768U, 65534U, 65535U
	};
	static int const intValues[] = {
		INT_MIN, INT_MIN + 1, -65537, -65536, -32769, -32768, -1, 0, 1, 32767, 32768,
		65535, 65536, INT_MAX - 1, INT_MAX
	};
	static unsigned int const unsignedIntValues[] = {
		0U, 1U, 32767U, 32768U, 65535U, 65536U, INT_MAX, (unsigned int)INT_MAX + 1U,
		UINT_MAX - 1U, UINT_MAX
	};
	static int64_t const signed64Values[] = {
		INT64_MIN, INT64_MIN + 1,
		-INT64_C(9007199254740993), -INT64_C(9007199254740992), -INT64_C(9007199254740991),
		-INT64_C(4294967297), -INT64_C(4294967296), -INT64_C(2147483649), -INT64_C(2147483648),
		-INT64_C(16777217), -INT64_C(16777216), -INT64_C(16777215), -INT64_C(65537),
		-INT64_C(32769), -1, 0, 1, 32767, 65535, INT64_C(16777215), INT64_C(16777216),
		INT64_C(16777217), INT64_C(2147483647), INT64_C(2147483648), INT64_C(4294967295),
		INT64_C(4294967296), INT64_C(9007199254740991), INT64_C(9007199254740992),
		INT64_C(9007199254740993), INT64_MAX - 1, INT64_MAX
	};
	static uint64_t const unsigned64Values[] = {
		0, 1, 255, 65535, UINT64_C(16777215), UINT64_C(16777216), UINT64_C(16777217),
		UINT64_C(2147483647), UINT64_C(2147483648), UINT64_C(4294967295), UINT64_C(4294967296),
		UINT64_C(9007199254740991), UINT64_C(9007199254740992), UINT64_C(9007199254740993),
		INT64_MAX, UINT64_C(9223372036854775808), UINT64_MAX - 1, UINT64_MAX
	};
	float const floatValues[] = {
		-__builtin_nanf("2"), __builtin_nanf("1"),
		-__builtin_inff(), -FLT_MAX,
		__builtin_nextafterf(-0x1p64f, -__builtin_inff()), -0x1p64f,
		__builtin_nextafterf(-0x1p64f, 0.0f),
		__builtin_nextafterf(-0x1p63f, -__builtin_inff()), -0x1p63f,
		__builtin_nextafterf(-0x1p63f, 0.0f),
		__builtin_nextafterf(-0x1p53f, -__builtin_inff()), -0x1p53f,
		__builtin_nextafterf(-0x1p53f, 0.0f),
		__builtin_nextafterf(-0x1p32f, -__builtin_inff()), -0x1p32f,
		__builtin_nextafterf(-0x1p32f, 0.0f), -2147483648.0f, -16777218.0f,
		-16777216.0f, -16777215.0f, -65537.0f, -65536.0f, -65535.0f, -32769.0f,
		-32768.0f, -32767.0f, -257.0f, -256.0f, -255.0f, -129.0f, -128.0f,
		-127.0f, -2.0f, -1.5f, __builtin_nextafterf(-1.0f, -__builtin_inff()), -1.0f,
		__builtin_nextafterf(-1.0f, __builtin_inff()), -0.5f, -FLT_MIN, -FLT_TRUE_MIN, -0.0f,
		0.0f, FLT_TRUE_MIN, FLT_MIN, 0.5f, __builtin_nextafterf(1.0f, 0.0f), 1.0f,
		__builtin_nextafterf(1.0f, __builtin_inff()), 1.5f, 2.0f, 127.0f, 128.0f, 129.0f,
		255.0f, 256.0f, 257.0f, 32767.0f, 32768.0f, 32769.0f, 65535.0f, 65536.0f,
		65537.0f, __builtin_nextafterf(0x1p24f, 0.0f), 0x1p24f,
		__builtin_nextafterf(0x1p24f, __builtin_inff()), 2147483648.0f,
		__builtin_nextafterf(0x1p32f, 0.0f), 0x1p32f,
		__builtin_nextafterf(0x1p32f, __builtin_inff()),
		__builtin_nextafterf(0x1p53f, 0.0f), 0x1p53f,
		__builtin_nextafterf(0x1p53f, __builtin_inff()),
		__builtin_nextafterf(0x1p63f, 0.0f), 0x1p63f,
		__builtin_nextafterf(0x1p63f, __builtin_inff()),
		__builtin_nextafterf(0x1p64f, 0.0f), 0x1p64f,
		__builtin_nextafterf(0x1p64f, __builtin_inff()), FLT_MAX, __builtin_inff()
	};
	double const doubleValues[] = {
		-__builtin_nan("2"), __builtin_nan("1"),
		-__builtin_inf(), -DBL_MAX,
		__builtin_nextafter(-0x1p64, -__builtin_inf()), -0x1p64,
		__builtin_nextafter(-0x1p64, 0.0),
		__builtin_nextafter(-0x1p63, -__builtin_inf()), -0x1p63,
		__builtin_nextafter(-0x1p63, 0.0),
		__builtin_nextafter(-0x1p53, -__builtin_inf()), -0x1p53,
		__builtin_nextafter(-0x1p53, 0.0),
		__builtin_nextafter(-0x1p32, -__builtin_inf()), -0x1p32,
		__builtin_nextafter(-0x1p32, 0.0), -2147483649.0, -2147483648.0,
		-16777217.0, -16777216.0, -16777215.0, -65537.0, -65536.0, -65535.0,
		-32769.0, -32768.0, -32767.0, -257.0, -256.0, -255.0, -129.0, -128.0,
		-127.0, -2.0, -1.5, __builtin_nextafter(-1.0, -__builtin_inf()), -1.0,
		__builtin_nextafter(-1.0, __builtin_inf()), -0.5, -DBL_MIN, -DBL_TRUE_MIN, -0.0,
		0.0, DBL_TRUE_MIN, DBL_MIN, 0.5, __builtin_nextafter(1.0, 0.0), 1.0,
		__builtin_nextafter(1.0, __builtin_inf()), 1.5, 2.0, 127.0, 128.0, 129.0,
		255.0, 256.0, 257.0, 32767.0, 32768.0, 32769.0, 65535.0, 65536.0, 65537.0,
		16777215.0, 16777216.0, 16777217.0,
		__builtin_nextafter(0x1p24, 0.0), 0x1p24, __builtin_nextafter(0x1p24, __builtin_inf()),
		2147483647.0, 2147483648.0, 2147483649.0, 4294967295.0, 4294967296.0,
		0x1p51 + 0.5, 0x1p52 - 0.5,
		__builtin_nextafter(0x1p53, 0.0), 0x1p53, __builtin_nextafter(0x1p53, __builtin_inf()),
		__builtin_nextafter(0x1p63, 0.0), 0x1p63, __builtin_nextafter(0x1p63, __builtin_inf()),
		__builtin_nextafter(0x1p64, 0.0), 0x1p64, __builtin_nextafter(0x1p64, __builtin_inf()),
		DBL_MAX, __builtin_inf()
	};
	static bool const boolValues[] = { false, true };
	size_t count = 0;

	static_assert(CHAR_BIT == 8, "NSNumber tests require eight-bit bytes");
	static_assert(sizeof(long) == sizeof(int64_t), "NSNumber tests require LP64");
	static_assert(sizeof(NSInteger) == sizeof(int64_t), "NSNumber tests require 64-bit NSInteger");

	for (size_t i = 0; i < sizeof(charValues) / sizeof(charValues[0]); ++i)
		NSNumberFixtureAddSigned(fixtures, &count, NSNumberFixtureSourceChar, @encode(char)[0], charValues[i],
			[NSNumber numberWithChar:charValues[i]]);
	for (size_t i = 0; i < sizeof(unsignedCharValues) / sizeof(unsignedCharValues[0]); ++i)
		NSNumberFixtureAddUnsigned(fixtures, &count, NSNumberFixtureSourceUnsignedChar,
			@encode(unsigned char)[0], unsignedCharValues[i],
			[NSNumber numberWithUnsignedChar:unsignedCharValues[i]]);
	for (size_t i = 0; i < sizeof(shortValues) / sizeof(shortValues[0]); ++i)
		NSNumberFixtureAddSigned(fixtures, &count, NSNumberFixtureSourceShort, @encode(short)[0], shortValues[i],
			[NSNumber numberWithShort:shortValues[i]]);
	for (size_t i = 0; i < sizeof(unsignedShortValues) / sizeof(unsignedShortValues[0]); ++i)
		NSNumberFixtureAddUnsigned(fixtures, &count, NSNumberFixtureSourceUnsignedShort,
			@encode(unsigned short)[0], unsignedShortValues[i],
			[NSNumber numberWithUnsignedShort:unsignedShortValues[i]]);
	for (size_t i = 0; i < sizeof(intValues) / sizeof(intValues[0]); ++i)
		NSNumberFixtureAddSigned(fixtures, &count, NSNumberFixtureSourceInt, @encode(int)[0], intValues[i],
			[NSNumber numberWithInt:intValues[i]]);
	for (size_t i = 0; i < sizeof(unsignedIntValues) / sizeof(unsignedIntValues[0]); ++i)
		NSNumberFixtureAddUnsigned(fixtures, &count, NSNumberFixtureSourceUnsignedInt,
			@encode(unsigned int)[0], unsignedIntValues[i],
			[NSNumber numberWithUnsignedInt:unsignedIntValues[i]]);

	for (size_t i = 0; i < sizeof(signed64Values) / sizeof(signed64Values[0]); ++i) {
		int64_t const value = signed64Values[i];
		NSNumberFixtureAddSigned(fixtures, &count, NSNumberFixtureSourceLong, @encode(long)[0], value,
			[NSNumber numberWithLong:(long)value]);
		NSNumberFixtureAddSigned(fixtures, &count, NSNumberFixtureSourceLongLong, @encode(long long)[0], value,
			[NSNumber numberWithLongLong:(long long)value]);
		NSNumberFixtureAddSigned(fixtures, &count, NSNumberFixtureSourceInteger, @encode(NSInteger)[0], value,
			[NSNumber numberWithInteger:(NSInteger)value]);
	}

	for (size_t i = 0; i < sizeof(unsigned64Values) / sizeof(unsigned64Values[0]); ++i) {
		uint64_t const value = unsigned64Values[i];
		NSNumberFixtureAddUnsigned(fixtures, &count, NSNumberFixtureSourceUnsignedLong, @encode(unsigned long)[0],
			value, [NSNumber numberWithUnsignedLong:(unsigned long)value]);
		NSNumberFixtureAddUnsigned(fixtures, &count, NSNumberFixtureSourceUnsignedLongLong,
			@encode(unsigned long long)[0], value,
			[NSNumber numberWithUnsignedLongLong:(unsigned long long)value]);
		NSNumberFixtureAddUnsigned(fixtures, &count, NSNumberFixtureSourceUnsignedInteger,
			@encode(NSUInteger)[0], value, [NSNumber numberWithUnsignedInteger:(NSUInteger)value]);
	}

	for (size_t i = 0; i < sizeof(boolValues) / sizeof(boolValues[0]); ++i)
		NSNumberFixtureAddUnsigned(fixtures, &count, NSNumberFixtureSourceBool, @encode(bool)[0],
			(uint64_t)boolValues[i], [NSNumber numberWithBool:boolValues[i]]);
	for (size_t i = 0; i < sizeof(floatValues) / sizeof(floatValues[0]); ++i)
		NSNumberFixtureAddFloating(fixtures, &count, NSNumberFixtureSourceFloat, @encode(float)[0],
			(double)floatValues[i], [NSNumber numberWithFloat:floatValues[i]]);
	for (size_t i = 0; i < sizeof(doubleValues) / sizeof(doubleValues[0]); ++i)
		NSNumberFixtureAddFloating(fixtures, &count, NSNumberFixtureSourceDouble, @encode(double)[0],
			doubleValues[i], [NSNumber numberWithDouble:doubleValues[i]]);

	return count;
}

static inline uint64_t
NSNumberFixtureMask(unsigned bits)
{
	return bits == 64 ? UINT64_MAX : (UINT64_C(1) << bits) - 1;
}

/* Exact truncation and modulo 2^bits for a finite IEEE-754 binary64 value. */
[[clang::no_sanitize("integer")]]
static inline uint64_t
NSNumberFixtureFloatingBits(double value, unsigned bits)
{
	uint64_t representation;
	uint64_t significand;
	uint64_t wrapped;
	unsigned exponentBits;
	int exponent;
	int shift;
	bool negative;

	memcpy(&representation, &value, sizeof(representation));
	negative = (representation >> 63) != 0;
	exponentBits = (unsigned)((representation >> 52) & UINT64_C(0x7ff));
	if (exponentBits == 0)
		return 0;

	exponent = (int)exponentBits - 1023;
	if (exponent < 0)
		return 0;

	significand = (representation & UINT64_C(0x000fffffffffffff)) | UINT64_C(0x0010000000000000);
	shift = exponent - 52;
	if (shift >= (int)bits)
		wrapped = 0;
	else if (shift >= 0)
		wrapped = significand << (unsigned)shift;
	else
		wrapped = significand >> (unsigned)-shift;

	wrapped &= NSNumberFixtureMask(bits);
	if (negative)
		wrapped = (UINT64_C(0) - wrapped) & NSNumberFixtureMask(bits);
	return wrapped;
}

static inline uint64_t
NSNumberFixtureExpectedUnsigned(NSNumberFixtureValue value, unsigned bits)
{
	switch (value.domain) {
	case NSNumberFixtureDomainSigned:
		return (uint64_t)value.v.signedValue & NSNumberFixtureMask(bits);
	case NSNumberFixtureDomainUnsigned:
		return value.v.unsignedValue & NSNumberFixtureMask(bits);
	case NSNumberFixtureDomainFloating:
		if (__builtin_isnan(value.v.floatingValue))
			return 0;
		if (__builtin_isinf(value.v.floatingValue))
			return __builtin_signbit(value.v.floatingValue) ? 0 : NSNumberFixtureMask(bits);
		return NSNumberFixtureFloatingBits(value.v.floatingValue, bits);
	}
}

static inline int64_t
NSNumberFixtureSignedFromBits(uint64_t value, unsigned bits)
{
	uint64_t const mask = NSNumberFixtureMask(bits);
	uint64_t const sign = UINT64_C(1) << (bits - 1);
	uint64_t extended = value & mask;
	int64_t result;

	if ((extended & sign) != 0)
		extended |= ~mask;
	memcpy(&result, &extended, sizeof(result));
	return result;
}

static inline int64_t
NSNumberFixtureExpectedSigned(NSNumberFixtureValue value, unsigned bits)
{
	if (value.domain == NSNumberFixtureDomainFloating) {
		if (__builtin_isnan(value.v.floatingValue))
			return 0;
		if (__builtin_isinf(value.v.floatingValue)) {
			uint64_t const bound = __builtin_signbit(value.v.floatingValue) ?
				(UINT64_C(1) << (bits - 1)) : ((UINT64_C(1) << (bits - 1)) - 1);
			return NSNumberFixtureSignedFromBits(bound, bits);
		}
	}

	return NSNumberFixtureSignedFromBits(NSNumberFixtureExpectedUnsigned(value, bits), bits);
}

static inline bool
NSNumberFixtureExpectedBool(NSNumberFixtureValue value)
{
	switch (value.domain) {
	case NSNumberFixtureDomainSigned:
		return value.v.signedValue != 0;
	case NSNumberFixtureDomainUnsigned:
		return value.v.unsignedValue != 0;
	case NSNumberFixtureDomainFloating:
		if (__builtin_isnan(value.v.floatingValue))
			return false;
		if (__builtin_isinf(value.v.floatingValue))
			return __builtin_signbit(value.v.floatingValue) == 0;
		return value.v.floatingValue != 0.0;
	}
}

static inline double
NSNumberFixtureExpectedDouble(NSNumberFixtureValue value)
{
	switch (value.domain) {
	case NSNumberFixtureDomainSigned:
		return (double)value.v.signedValue;
	case NSNumberFixtureDomainUnsigned:
		return (double)value.v.unsignedValue;
	case NSNumberFixtureDomainFloating:
		return value.v.floatingValue;
	}
}

static inline float
NSNumberFixtureExpectedFloat(NSNumberFixtureValue value)
{
	return (float)NSNumberFixtureExpectedDouble(value);
}

static inline bool
NSNumberFixtureFloatMatches(float actual, float expected)
{
	if (__builtin_isnan(expected))
		return __builtin_isnan(actual);

	return memcmp(&actual, &expected, sizeof(actual)) == 0;
}

static inline bool
NSNumberFixtureDoubleMatches(double actual, double expected)
{
	if (__builtin_isnan(expected))
		return __builtin_isnan(actual);

	return memcmp(&actual, &expected, sizeof(actual)) == 0;
}

static inline NSComparisonResult
NSNumberFixtureCompareSignedToUnsigned(int64_t signedValue, uint64_t unsignedValue)
{
	if (signedValue < 0)
		return NSOrderedAscending;

	uint64_t const converted = (uint64_t)signedValue;
	return (NSComparisonResult)((converted > unsignedValue) - (converted < unsignedValue));
}

static inline NSComparisonResult
NSNumberFixtureCompareSignedToFloating(int64_t signedValue, double floatingValue)
{
	if (__builtin_isnan(floatingValue))
		return NSOrderedDescending;
	if (floatingValue < -0x1p63)
		return NSOrderedDescending;
	if (floatingValue >= 0x1p63)
		return NSOrderedAscending;

	double const integral = __builtin_trunc(floatingValue);
	int64_t const converted = (int64_t)integral;
	NSComparisonResult const integerComparison =
		(NSComparisonResult)((signedValue > converted) - (signedValue < converted));
	if (integerComparison != NSOrderedSame)
		return integerComparison;

	return (NSComparisonResult)((integral > floatingValue) - (integral < floatingValue));
}

static inline NSComparisonResult
NSNumberFixtureCompareUnsignedToFloating(uint64_t unsignedValue, double floatingValue)
{
	if (__builtin_isnan(floatingValue))
		return NSOrderedDescending;
	if (floatingValue < 0.0)
		return NSOrderedDescending;
	if (floatingValue >= 0x1p64)
		return NSOrderedAscending;

	double const integral = __builtin_trunc(floatingValue);
	uint64_t const converted = (uint64_t)integral;
	NSComparisonResult const integerComparison =
		(NSComparisonResult)((unsignedValue > converted) - (unsignedValue < converted));
	if (integerComparison != NSOrderedSame)
		return integerComparison;

	return integral < floatingValue ? NSOrderedAscending : NSOrderedSame;
}

static inline NSComparisonResult
NSNumberFixtureCompareValues(NSNumberFixtureValue value, NSNumberFixtureValue otherValue)
{
	if (value.domain == NSNumberFixtureDomainSigned) {
		if (otherValue.domain == NSNumberFixtureDomainSigned)
			return (NSComparisonResult)((value.v.signedValue > otherValue.v.signedValue) -
				(value.v.signedValue < otherValue.v.signedValue));
		if (otherValue.domain == NSNumberFixtureDomainUnsigned)
			return NSNumberFixtureCompareSignedToUnsigned(value.v.signedValue, otherValue.v.unsignedValue);
		return NSNumberFixtureCompareSignedToFloating(value.v.signedValue, otherValue.v.floatingValue);
	}

	if (value.domain == NSNumberFixtureDomainUnsigned) {
		if (otherValue.domain == NSNumberFixtureDomainSigned)
			return (NSComparisonResult)-NSNumberFixtureCompareSignedToUnsigned(otherValue.v.signedValue,
				value.v.unsignedValue);
		if (otherValue.domain == NSNumberFixtureDomainUnsigned)
			return (NSComparisonResult)((value.v.unsignedValue > otherValue.v.unsignedValue) -
				(value.v.unsignedValue < otherValue.v.unsignedValue));
		return NSNumberFixtureCompareUnsignedToFloating(value.v.unsignedValue, otherValue.v.floatingValue);
	}

	if (otherValue.domain == NSNumberFixtureDomainSigned)
		return (NSComparisonResult)-NSNumberFixtureCompareSignedToFloating(otherValue.v.signedValue,
			value.v.floatingValue);
	if (otherValue.domain == NSNumberFixtureDomainUnsigned)
		return (NSComparisonResult)-NSNumberFixtureCompareUnsignedToFloating(otherValue.v.unsignedValue,
			value.v.floatingValue);

	if (__builtin_isnan(value.v.floatingValue))
		return __builtin_isnan(otherValue.v.floatingValue) ? NSOrderedSame : NSOrderedAscending;
	if (__builtin_isnan(otherValue.v.floatingValue))
		return NSOrderedDescending;
	return (NSComparisonResult)((value.v.floatingValue > otherValue.v.floatingValue) -
		(value.v.floatingValue < otherValue.v.floatingValue));
}

#endif

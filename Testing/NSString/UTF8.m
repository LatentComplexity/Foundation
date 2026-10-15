#import <Foundation/NSString.h>
#import "Test.h"

#include <stdlib.h>
#include <string.h>

typedef struct UTF8Fixture {
	unsigned char const *bytes;
	NSUInteger length;
} UTF8Fixture;

static void
TestValidString(unsigned char const *bytes, NSUInteger byteLength, unichar const *characters,
	NSUInteger characterLength)
{
	NSString *string = [[NSString alloc] initWithBytes:bytes length:byteLength encoding:NSUTF8StringEncoding];

	TEST(string != nil);
	if (string == nil)
		return;

	TEST_EQ_UNSIGNED(string.length, characterLength);
	for (NSUInteger i = 0; i < characterLength; ++i)
		TEST_EQ_UNSIGNED([string characterAtIndex:i], characters[i]);
}

static void
TestValidUTF8(void)
{
	@autoreleasepool {
		unsigned char const ascii[] = { 'F', 'o', 'u', 'n', 'd', 'a', 't', 'i', 'o', 'n' };
		unichar const expected[] = { 'F', 'o', 'u', 'n', 'd', 'a', 't', 'i', 'o', 'n' };

		TestValidString(ascii, sizeof(ascii), expected, sizeof(expected) / sizeof(expected[0]));
	}

	@autoreleasepool {
		unsigned char const bytes[] = { 0xC2, 0x80, 0xDF, 0xBF };
		unichar const expected[] = { 0x0080, 0x07FF };

		TestValidString(bytes, sizeof(bytes), expected, sizeof(expected) / sizeof(expected[0]));
	}

	@autoreleasepool {
		unsigned char const bytes[] = {
			0xE0, 0xA0, 0x80,
			0xED, 0x9F, 0xBF,
			0xEE, 0x80, 0x80,
			0xEF, 0xBF, 0xBF
		};
		unichar const expected[] = { 0x0800, 0xD7FF, 0xE000, 0xFFFF };

		TestValidString(bytes, sizeof(bytes), expected, sizeof(expected) / sizeof(expected[0]));
	}

	@autoreleasepool {
		unsigned char const bytes[] = {
			0xF0, 0x90, 0x80, 0x80,
			0xF4, 0x8F, 0xBF, 0xBF
		};
		unichar const expected[] = { 0xD800, 0xDC00, 0xDBFF, 0xDFFF };

		TestValidString(bytes, sizeof(bytes), expected, sizeof(expected) / sizeof(expected[0]));
	}
}

static void
TestInvalidUTF8(void)
{
	@autoreleasepool {
		unsigned char const strayFirst[] = { 0x80 };
		unsigned char const strayLast[] = { 0xBF };
		unsigned char const overlongTwoFirst[] = { 0xC0, 0x80 };
		unsigned char const overlongTwoLast[] = { 0xC1, 0xBF };
		unsigned char const truncatedTwo[] = { 0xC2 };
		unsigned char const badTwoContinuation[] = { 0xC2, 0xC0 };
		unsigned char const overlongThree[] = { 0xE0, 0x9F, 0xBF };
		unsigned char const truncatedThree[] = { 0xE0, 0xA0 };
		unsigned char const badThreeSecond[] = { 0xE1, 0x40, 0x80 };
		unsigned char const badThreeThird[] = { 0xE1, 0x80, 0x40 };
		unsigned char const surrogateFirst[] = { 0xED, 0xA0, 0x80 };
		unsigned char const surrogateLast[] = { 0xED, 0xBF, 0xBF };
		unsigned char const overlongFour[] = { 0xF0, 0x8F, 0xBF, 0xBF };
		unsigned char const truncatedFour[] = { 0xF0, 0x90, 0x80 };
		unsigned char const badFourSecond[] = { 0xF1, 0x40, 0x80, 0x80 };
		unsigned char const badFourThird[] = { 0xF1, 0x80, 0x40, 0x80 };
		unsigned char const badFourFourth[] = { 0xF1, 0x80, 0x80, 0x40 };
		unsigned char const tooLargeBoundary[] = { 0xF4, 0x90, 0x80, 0x80 };
		unsigned char const tooLargeLead[] = { 0xF5, 0x80, 0x80, 0x80 };
		unsigned char const invalidLead[] = { 0xFF };
		UTF8Fixture const fixtures[] = {
			{ strayFirst, sizeof(strayFirst) },
			{ strayLast, sizeof(strayLast) },
			{ overlongTwoFirst, sizeof(overlongTwoFirst) },
			{ overlongTwoLast, sizeof(overlongTwoLast) },
			{ truncatedTwo, sizeof(truncatedTwo) },
			{ badTwoContinuation, sizeof(badTwoContinuation) },
			{ overlongThree, sizeof(overlongThree) },
			{ truncatedThree, sizeof(truncatedThree) },
			{ badThreeSecond, sizeof(badThreeSecond) },
			{ badThreeThird, sizeof(badThreeThird) },
			{ surrogateFirst, sizeof(surrogateFirst) },
			{ surrogateLast, sizeof(surrogateLast) },
			{ overlongFour, sizeof(overlongFour) },
			{ truncatedFour, sizeof(truncatedFour) },
			{ badFourSecond, sizeof(badFourSecond) },
			{ badFourThird, sizeof(badFourThird) },
			{ badFourFourth, sizeof(badFourFourth) },
			{ tooLargeBoundary, sizeof(tooLargeBoundary) },
			{ tooLargeLead, sizeof(tooLargeLead) },
			{ invalidLead, sizeof(invalidLead) }
		};

		for (NSUInteger i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
			NSString *copied = [[NSString alloc] initWithBytes:fixtures[i].bytes length:fixtures[i].length
				encoding:NSUTF8StringEncoding];
			void *bytes = malloc(fixtures[i].length);
			NSString *adopted;

			memcpy(bytes, fixtures[i].bytes, fixtures[i].length);
			adopted = [[NSString alloc] initWithBytesNoCopy:bytes length:fixtures[i].length
				encoding:NSUTF8StringEncoding freeWhenDone:true];

			TESTF(copied == nil, "copying fixture %zu", (size_t)i);
			TESTF(adopted == nil, "no-copy fixture %zu", (size_t)i);
		}
	}
}

int
main(void)
{
	TestValidUTF8();
	TestInvalidUTF8();

	return TestFinish();
}

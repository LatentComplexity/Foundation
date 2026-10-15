#import <FoundationPrivate/NSObject/NSTypeEncodingString.h>
#import <Foundation/NSValue.h>
#import "Test.h"

int
main(void)
{
	@autoreleasepool {
		char const *const malformed[] = {
			"[2305843009213693952C]", /* First byte count outside the internal bit range. */
			"[288230376151711744q]", /* Multiplication overflows at a different element width. */
			"{Sum=[2305843009213693951C]C}",
			"{Round=q[2305843009213693937C]}", /* First final-padding overflow. */
			"{Round=[2305843009213693951C][0q]}", /* Field-alignment overflow. */
			"[2[18446744073709551615v]]", /* Leaf multiplication with size zero. */
			"{Leaves=[18446744073709551615v]v}", /* Leaf addition with size zero. */
			"[0[2305843009213693952C]]", /* A zero outer count cannot hide an invalid element. */
			"^[2305843009213693952C]",
			"[18446744073709551616C]",
			"q[2305843009213693952C]", /* Validation reaches subsequent components. */
			"{Broken=[2305843009213693952C]" /* Syntax rejection precedes measurement. */
		};
		for (unsigned scheme = 0; scheme <= NSTypeEncodingStringSchemeInvocable; ++scheme)
			for (NSUInteger i = 0; i < sizeof(malformed) / sizeof(malformed[0]); ++i) {
				NSTypeEncodingStringResult result = NSTypeEncodingStringValidate(
					(NSTypeEncodingStringScheme)scheme, malformed[i]);
				TEST_EQ_UNSIGNED(result.status, NSTypeEncodingStringStatusMalformed);
				TEST(result.reason != nil);
			}

		char const *const storableOverflow[] = {
			"b18446744073709551609", /* First width whose byte rounding overflows. */
			"{Bits=b18446744073709551615b1}",
			"{Bits=b18446744073709551615}",
			"(Bits=b18446744073709551615)",
			"(Union=q[2305843009213693951C])",
			"[576460752303423488jD]"
		};
		for (NSUInteger i = 0; i < sizeof(storableOverflow) / sizeof(storableOverflow[0]); ++i) {
			NSTypeEncodingStringResult result = NSTypeEncodingStringValidate(
				NSTypeEncodingStringSchemeStorable, storableOverflow[i]);
			TEST_EQ_UNSIGNED(result.status, NSTypeEncodingStringStatusMalformed);
			TEST(result.reason != nil);
		}

		/* Public storable-type callers reject the description before measuring or copying its value. */
		char byte = 0;
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)NSGetSizeAndAlignment("[2305843009213693952C]", nullptr, nullptr));
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[NSValue valueWithBytes:&byte objCType:"[2305843009213693952C]"]);
	}
	return TestFinish();
}

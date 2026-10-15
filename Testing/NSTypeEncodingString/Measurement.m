#import <FoundationPrivate/NSObject/NSTypeEncodingString.h>
#import "Test.h"

#include <string.h>

/* These tests measure descriptions only: none of the enormous represented values is allocated. */
static void
TestLayoutBoundaries(void)
{
	struct Fixture { char const *type; NSUInteger size, alignment, leaves; } const fixtures[] = {
		{"[2305843009213693951C]", 2305843009213693951UL, 1, 2305843009213693951UL},
		{"{Aligned=[288230376151711743q]}", 2305843009213693944UL, 8, 288230376151711743UL},
		{"{Round=q[2305843009213693936C]}", 2305843009213693944UL, 8, 2305843009213693937UL},
		{"[18446744073709551615v]", 0, 1, 18446744073709551615UL},
		{"[0[18446744073709551615v]]", 0, 1, 0},
		{"[18446744073709551615{Empty=}]", 0, 1, 0},
		{"{Leaves=[18446744073709551614v]v}", 0, 1, 18446744073709551615UL},
		{"r^[2305843009213693951C]", 8, 8, 1},
		{"{Pair=cd}", 16, 8, 2},
		{"[3{Pair=cd}]", 48, 8, 6}
	};
	for (unsigned scheme = 0; scheme <= NSTypeEncodingStringSchemeInvocable; ++scheme)
		for (NSUInteger i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
			NSTypeEncodingStringResult result = NSTypeEncodingStringValidate(
				(NSTypeEncodingStringScheme)scheme, fixtures[i].type);
			TEST_EQ_UNSIGNED(result.status, NSTypeEncodingStringStatusOK);
			if (result.status != NSTypeEncodingStringStatusOK) continue;
			NSUInteger size, alignment, leaves;
			char const *end = NSTypeEncodingStringMeasure(fixtures[i].type, &size, &alignment, &leaves);
			TEST_EQ_UNSIGNED(size, fixtures[i].size);
			TEST_EQ_UNSIGNED(alignment, fixtures[i].alignment);
			TEST_EQ_UNSIGNED(leaves, fixtures[i].leaves);
			TEST(end == fixtures[i].type + strlen(fixtures[i].type));
		}
}

static void
TestStorableLayouts(void)
{
	struct Fixture { char const *type; NSUInteger size, alignment, leaves; } const fixtures[] = {
		{"b18446744073709551608", 2305843009213693951UL, 1, 1},
		{"{Bits=b18446744073709551600b8}", 2305843009213693951UL, 1, 2},
		{"(Union=[2305843009213693951C][2305843009213693951C])",
			2305843009213693951UL, 1, 2305843009213693951UL},
		{"(Bits=b18446744073709551608b8)", 2305843009213693951UL, 1, 1},
		{"{Complex=cdjD}", 48, 16, 3},
		{"{Bits=b3b5i}", 8, 4, 3}
	};
	for (NSUInteger i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
		NSTypeEncodingStringResult result = NSTypeEncodingStringValidate(
			NSTypeEncodingStringSchemeStorable, fixtures[i].type);
		TEST_EQ_UNSIGNED(result.status, NSTypeEncodingStringStatusOK);
		if (result.status != NSTypeEncodingStringStatusOK) continue;
		NSUInteger size, alignment, leaves;
		(void)NSTypeEncodingStringMeasure(fixtures[i].type, &size, &alignment, &leaves);
		TEST_EQ_UNSIGNED(size, fixtures[i].size);
		TEST_EQ_UNSIGNED(alignment, fixtures[i].alignment);
		TEST_EQ_UNSIGNED(leaves, fixtures[i].leaves);
	}
}

int
main(void)
{
	@autoreleasepool {
		TestLayoutBoundaries();
		TestStorableLayouts();
	}
	return TestFinish();
}

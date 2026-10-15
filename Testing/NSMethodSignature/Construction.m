#import <Foundation/NSMethodSignature.h>
#import "Test.h"

#include <stdio.h>
#include <string.h>

typedef struct InvocableTypeFixture {
	char const *type;
	NSUInteger size;
	NSUInteger mayReturn;
} InvocableTypeFixture;

static NSUInteger
PromotedSize(NSUInteger size)
{
	NSUInteger const word = sizeof(void *);
	NSUInteger const remainder = size % word;

	return remainder == 0 ? size : size + word - remainder;
}

static void
TestInvocableType(InvocableTypeFixture const *fixture)
{
	char argumentEncoding[256];
	int const argumentLength = snprintf(argumentEncoding, sizeof(argumentEncoding), "v@:%s", fixture->type);
	NSMethodSignature *argumentSignature;

	TEST(argumentLength > 0 && (NSUInteger)argumentLength < sizeof(argumentEncoding));
	if (argumentLength <= 0 || (NSUInteger)argumentLength >= sizeof(argumentEncoding))
		return;

	argumentSignature = [NSMethodSignature signatureWithObjCTypes:argumentEncoding];
	TEST_STR_EQ(argumentSignature.methodReturnType, "v");
	TEST_EQ_UNSIGNED(argumentSignature.methodReturnLength, 0);
	TEST_EQ_UNSIGNED(argumentSignature.numberOfArguments, 3);
	TEST_EQ_UNSIGNED(argumentSignature.frameLength,
		PromotedSize(sizeof(id)) + PromotedSize(sizeof(SEL)) + PromotedSize(fixture->size));
	TEST_STR_EQ([argumentSignature getArgumentTypeAtIndex:0], "@");
	TEST_STR_EQ([argumentSignature getArgumentTypeAtIndex:1], ":");
	TEST_STR_EQ([argumentSignature getArgumentTypeAtIndex:2], fixture->type);

	if (fixture->mayReturn) {
		char returnEncoding[256];
		int const returnLength = snprintf(returnEncoding, sizeof(returnEncoding), "%s@:", fixture->type);
		NSMethodSignature *returnSignature;

		TEST(returnLength > 0 && (NSUInteger)returnLength < sizeof(returnEncoding));
		if (returnLength <= 0 || (NSUInteger)returnLength >= sizeof(returnEncoding))
			return;

		returnSignature = [NSMethodSignature signatureWithObjCTypes:returnEncoding];
		TEST_STR_EQ(returnSignature.methodReturnType, fixture->type);
		TEST_EQ_UNSIGNED(returnSignature.methodReturnLength, fixture->size);
		TEST_EQ_UNSIGNED(returnSignature.numberOfArguments, 2);
		TEST_EQ_UNSIGNED(returnSignature.frameLength,
			PromotedSize(sizeof(id)) + PromotedSize(sizeof(SEL)));
	}
}

static void
TestEveryInvocableType(void)
{
	@autoreleasepool {
		/*
		 * This is the complete Invocable alphabet plus representative instances of every recursive form.
		 * Arrays are valid arguments and fields, but NSMethodSignature separately forbids returning one by value.
		 */
		InvocableTypeFixture const fixtures[] = {
			{ "c", sizeof(char), true },
			{ "i", sizeof(int), true },
			{ "s", sizeof(short), true },
			{ "l", sizeof(long), true },
			{ "q", sizeof(long long), true },
			{ "C", sizeof(unsigned char), true },
			{ "I", sizeof(unsigned int), true },
			{ "S", sizeof(unsigned short), true },
			{ "L", sizeof(unsigned long), true },
			{ "Q", sizeof(unsigned long long), true },
			{ "f", sizeof(float), true },
			{ "d", sizeof(double), true },
			{ "B", sizeof(bool), true },
			{ "v", 0, true },
			{ "*", sizeof(char *), true },
			{ "#", sizeof(Class), true },
			{ ":", sizeof(SEL), true },
			{ "?", 0, true },
			{ "@", sizeof(id), true },
			{ "@?", sizeof(void *), true },
			{ "^i", sizeof(void *), true },
			{ "^^d", sizeof(void *), true },
			{ "^?", sizeof(void *), true },
			{ "^[3C]", sizeof(void *), true },
			{ "^{Pair=ii}", sizeof(void *), true },
			{ "[0c]", sizeof(void *), false },
			{ "[3i]", sizeof(void *), false },
			{ "[2[3C]]", sizeof(void *), false },
			{ "[2{Pair=ii}]", sizeof(void *), false },
			{ "rn[4f]", sizeof(void *), false },
			{ "{Empty=}", 0, true },
			{ "{Opaque}", 0, true },
			{ "{Pair=ii}", 2 * sizeof(int), true },
			{ "{Nested={Pair=ii}[3d]^v}", 40, true },
			{ "rc", sizeof(char), true },
			{ "ni", sizeof(int), true },
			{ "Ns", sizeof(short), true },
			{ "ol", sizeof(long), true },
			{ "Oq", sizeof(long long), true },
			{ "Rf", sizeof(float), true },
			{ "Vd", sizeof(double), true },
			{ "AB", sizeof(bool), true },
			{ "rnNoORVAc", sizeof(char), true }
		};

		for (NSUInteger i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i)
			TestInvocableType(&fixtures[i]);
	}
}

static void
TestOffsetsAndLongSignatures(void)
{
	@autoreleasepool {
		char const *const expectedArguments[] = {
			"@", ":", "c", "i", "s", "l", "q", "C", "I", "S", "L", "Q", "f", "d", "B", "v",
			"*", "#", ":", "?", "@", "@?", "^i", "^^d", "[3i]", "{Pair=ii}"
		};
		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:
			"v512@0:8c16i24s32l40q48C56I64S72L80Q88f96d104B112v120*128#136:144?152"
			"@160@?168^i176^^d184[3i]192{Pair=ii}208"];

		TEST_EQ_UNSIGNED(signature.numberOfArguments,
			sizeof(expectedArguments) / sizeof(expectedArguments[0]));
		for (NSUInteger i = 0; i < sizeof(expectedArguments) / sizeof(expectedArguments[0]); ++i)
			TEST_STR_EQ_MSG([signature getArgumentTypeAtIndex:i], expectedArguments[i],
				expectedArguments[i]);

		NSMethodSignature *maximumOffset = [NSMethodSignature signatureWithObjCTypes:
			"v18446744073709551615@0:0000000000000000000000008"];
		TEST_EQ_UNSIGNED(maximumOffset.numberOfArguments, 2);
		TEST_STR_EQ(maximumOffset.methodReturnType, "v");
		TEST_STR_EQ([maximumOffset getArgumentTypeAtIndex:0], "@");
		TEST_STR_EQ([maximumOffset getArgumentTypeAtIndex:1], ":");
	}
}

static void
TestInputIsCopied(void)
{
	@autoreleasepool {
		char types[] = "i24@0:8ri16";
		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:types];

		memset(types, 'x', strlen(types));
		TEST_STR_EQ(signature.methodReturnType, "i");
		TEST_STR_EQ([signature getArgumentTypeAtIndex:0], "@");
		TEST_STR_EQ([signature getArgumentTypeAtIndex:1], ":");
		TEST_STR_EQ([signature getArgumentTypeAtIndex:2], "ri");
	}
}

static void
TestRepresentableSizeBoundaries(void)
{
	@autoreleasepool {
		/* Signatures allocate metadata only, so these boundaries need no enormous argument buffers. */
		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:
			"{Huge=[2305843009213693951C]}@:[2305843009213693951C]"];
		TEST_EQ_UNSIGNED(signature.methodReturnLength, 2305843009213693951UL);
		TEST_EQ_UNSIGNED(signature.frameLength, 3 * sizeof(void *));
		TEST_STR_EQ([signature getArgumentTypeAtIndex:2], "[2305843009213693951C]");

		/* Largest pointer-word-aligned frame length that fits NSUInteger, including self and _cmd. */
		signature = [NSMethodSignature signatureWithObjCTypes:
			"v@:{A=[2305843009213693951C]}{A=[2305843009213693951C]}"
			"{A=[2305843009213693951C]}{A=[2305843009213693951C]}"
			"{A=[2305843009213693951C]}{A=[2305843009213693951C]}"
			"{A=[2305843009213693951C]}{Last=[2305843009213693928C]}"];
		TEST_EQ_UNSIGNED(signature.frameLength, 18446744073709551608UL);
		TEST_EQ_UNSIGNED(signature.numberOfArguments, 10);
	}
}

int
main(void)
{
	TestEveryInvocableType();
	TestOffsetsAndLongSignatures();
	TestInputIsCopied();
	TestRepresentableSizeBoundaries();

	return TestFinish();
}

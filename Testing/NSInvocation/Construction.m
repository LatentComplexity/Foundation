#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSObject.h>
#import "Test.h"

#import <objc/runtime.h>

#include <string.h>

typedef struct {
	long a;
	long b;
} Pair;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wc++-compat"
#pragma clang diagnostic ignored "-Wgnu-empty-struct"
typedef struct {
} Empty;
#pragma clang diagnostic pop

static void
TestBasicConstruction(void)
{
	@autoreleasepool {
		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"q@:q"];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		long argument = 0x123456789L;
		long result = -1;

		TEST_STR_EQ(object_getClassName(invocation), "NSInvocation");
		TEST(invocation.methodSignature == signature);
		TEST(invocation.target == nil);
		TEST(invocation.selector == nullptr);
		TEST(invocation.argumentsRetained == false);

		[invocation getArgument:&result atIndex:2];
		TEST_EQ_SIGNED(result, 0);
		[invocation getReturnValue:&result];
		TEST_EQ_SIGNED(result, 0);

		[invocation setArgument:&argument atIndex:2];
		result = 0;
		[invocation getArgument:&result atIndex:2];
		TEST_EQ_SIGNED(result, argument);

		result = 0x7654321L;
		[invocation setReturnValue:&result];
		result = 0;
		[invocation getReturnValue:&result];
		TEST_EQ_SIGNED(result, 0x7654321L);
	}
}

static void
TestTargetAndSelectorSlots(void)
{
	@autoreleasepool {
		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		NSObject *first = [NSObject new];
		NSObject *second = [NSObject new];
		__unsafe_unretained id target = nil;
		SEL selector = nullptr;

		invocation.target = first;
		invocation.selector = @selector(description);
		[invocation getArgument:&target atIndex:0];
		[invocation getArgument:&selector atIndex:1];
		TEST(target == first);
		TEST(selector == @selector(description));

		target = second;
		selector = @selector(hash);
		[invocation setArgument:&target atIndex:0];
		[invocation setArgument:&selector atIndex:1];
		TEST(invocation.target == second);
		TEST(invocation.selector == @selector(hash));

		/* A void invocation has no return buffer, but the non-null location remains a valid no-op. */
		unsigned char untouched = 0xa5;
		[invocation setReturnValue:&untouched];
		[invocation getReturnValue:&untouched];
		TEST_EQ_UNSIGNED(untouched, 0xa5);
	}
}

static void
TestEveryBufferSize(void)
{
	@autoreleasepool {
		NSInvocation *one = [NSInvocation invocationWithMethodSignature:
			[NSMethodSignature signatureWithObjCTypes:"c@:c"]];
		char input = (char)0x5a;
		unsigned char guarded[8];

		memset(guarded, 0xa5, sizeof(guarded));
		[one setArgument:&input atIndex:2];
		[one getArgument:&guarded[3] atIndex:2];
		TEST_EQ_UNSIGNED(guarded[2], 0xa5);
		TEST_EQ_UNSIGNED(guarded[3], 0x5a);
		TEST_EQ_UNSIGNED(guarded[4], 0xa5);

		[one setReturnValue:&input];
		memset(guarded, 0xa5, sizeof(guarded));
		[one getReturnValue:&guarded[3]];
		TEST_EQ_UNSIGNED(guarded[2], 0xa5);
		TEST_EQ_UNSIGNED(guarded[3], 0x5a);
		TEST_EQ_UNSIGNED(guarded[4], 0xa5);
	}

	@autoreleasepool {
		NSInvocation *twelve = [NSInvocation invocationWithMethodSignature:
			[NSMethodSignature signatureWithObjCTypes:"{Triple=iii}@:{Triple=iii}"]];
		struct { int a, b, c; } input = { 1, 2, 3 };
		struct { int a, b, c; } output = { 0, 0, 0 };

		[twelve setArgument:&input atIndex:2];
		[twelve getArgument:&output atIndex:2];
		TEST_BYTES_EQ(&output, &input, sizeof(input));

		[twelve setReturnValue:&input];
		memset(&output, 0, sizeof(output));
		[twelve getReturnValue:&output];
		TEST_BYTES_EQ(&output, &input, sizeof(input));
	}

	@autoreleasepool {
		NSInvocation *sixteen = [NSInvocation invocationWithMethodSignature:
			[NSMethodSignature signatureWithObjCTypes:"{Pair=qq}@:{Pair=qq}"]];
		Pair input = { 0x112233445566778L, 0x776655443322110L };
		Pair output = { 0, 0 };

		[sixteen setArgument:&input atIndex:2];
		[sixteen getArgument:&output atIndex:2];
		TEST_BYTES_EQ(&output, &input, sizeof(input));
		[sixteen setReturnValue:&input];
		memset(&output, 0, sizeof(output));
		[sixteen getReturnValue:&output];
		TEST_BYTES_EQ(&output, &input, sizeof(input));
	}

	@autoreleasepool {
		NSInvocation *large = [NSInvocation invocationWithMethodSignature:
			[NSMethodSignature signatureWithObjCTypes:"{Large=qqqqq}@:{Large=qqqqq}"]];
		long input[5] = { 1, 2, 3, 4, 5 };
		long output[5] = { 0 };

		[large setArgument:input atIndex:2];
		[large getArgument:output atIndex:2];
		TEST_BYTES_EQ(output, input, sizeof(input));
		[large setReturnValue:input];
		memset(output, 0, sizeof(output));
		[large getReturnValue:output];
		TEST_BYTES_EQ(output, input, sizeof(input));
	}
}

static void
TestZeroSizedArguments(void)
{
	@autoreleasepool {
		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:{Empty=}?q"];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		Empty empty = { };
		unsigned char unknown = 0;
		long value = 73;
		long got = 0;

		/* Empty and unknown components consume no storage and must not disturb the following argument. */
		[invocation setArgument:&empty atIndex:2];
		[invocation getArgument:&empty atIndex:2];
		[invocation setArgument:&unknown atIndex:3];
		[invocation getArgument:&unknown atIndex:3];
		[invocation setArgument:&value atIndex:4];
		[invocation getArgument:&got atIndex:4];
		TEST_EQ_SIGNED(got, value);
	}
}

static void
TestAdjustedArrayStorage(void)
{
	char const *const encodings[] = {
		"v@:[0c]", "v@:[1c]", "v@:[4f]", "v@:[5d]", "v@:[17i]",
		"v@:rn[4f]", "v@:[2[4f]]", "v@:[2{Pair=qq}]", "v@:[3{Empty=}]"
	};

	for (NSUInteger i = 0; i < sizeof(encodings) / sizeof(encodings[0]); ++i)
		@autoreleasepool {
			NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:encodings[i]];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
			unsigned char source[128] = {};
			unsigned char guarded[128];
			void *pointer = source;
			void *got = nullptr;

			TEST_EQ_UNSIGNED(signature.frameLength, 3 * sizeof(void *));
			/* Unaligned storage is legal for set/getArgument. Padding keeps an old implementation's oversized
			 * copies inside the arrays, allowing the canary assertion to report the defect without a crash. */
			memcpy(source + 3, &pointer, sizeof(pointer));
			[invocation setArgument:source + 3 atIndex:2];
			memset(guarded, 0xa5, sizeof(guarded));
			[invocation getArgument:guarded + 3 atIndex:2];
			memcpy(&got, guarded + 3, sizeof(got));
			TESTF(got == pointer, "pointer round trip for %s", encodings[i]);
			for (NSUInteger j = 0; j < sizeof(guarded); ++j)
				if (j < 3 || j >= 3 + sizeof(pointer))
					TESTF(guarded[j] == 0xa5, "array argument overwrote byte %lu for %s",
						(unsigned long)j, encodings[i]);
		}
}

static void
TestIndependentStorage(void)
{
	@autoreleasepool {
		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"{Pair=qq}@:{Pair=qq}"];
		NSInvocation *first = [NSInvocation invocationWithMethodSignature:signature];
		NSInvocation *second = [NSInvocation invocationWithMethodSignature:signature];
		Pair a = { 1, 2 };
		Pair b = { 3, 4 };
		Pair got = { 0, 0 };

		[first setArgument:&a atIndex:2];
		[second setArgument:&b atIndex:2];
		[first setReturnValue:&b];
		[second setReturnValue:&a];

		[first getArgument:&got atIndex:2];
		TEST_BYTES_EQ(&got, &a, sizeof(a));
		[second getArgument:&got atIndex:2];
		TEST_BYTES_EQ(&got, &b, sizeof(b));
		[first getReturnValue:&got];
		TEST_BYTES_EQ(&got, &b, sizeof(b));
		[second getReturnValue:&got];
		TEST_BYTES_EQ(&got, &a, sizeof(a));
	}
}

int
main(void)
{
	TestBasicConstruction();
	TestTargetAndSelectorSlots();
	TestEveryBufferSize();
	TestZeroSizedArguments();
	TestAdjustedArrayStorage();
	TestIndependentStorage();

	return TestFinish();
}

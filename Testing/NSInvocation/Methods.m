#import "Fixtures.h"
#import "Test.h"

#include <stdint.h>
#include <string.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-strict"
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"

typedef int (*IntCall)(id, SEL, int);
typedef long (*LongCall)(id, SEL, long);

static NSInvocation *
InvocationFor(SEL selector)
{
	NSMethodSignature *signature = [InvocationSubject instanceMethodSignatureForSelector:selector];
	NSInvocation *invocation;

	invocation = [NSInvocation invocationWithMethodSignature:signature];

	invocation.selector = selector;
	return invocation;
}

static void
InvokeUnary(InvocationSubject *subject, SEL selector, void *input, void *output)
{
	NSInvocation *invocation = InvocationFor(selector);

	[invocation setArgument:input atIndex:2];
	[invocation invokeWithTarget:subject];
	[invocation getReturnValue:output];
}

#define TEST_INTEGRAL(Type, selectorName, inputValue) \
	do { \
		Type _input = (inputValue); \
		Type _output = (Type)0; \
		InvokeUnary(subject, @selector(selectorName), (void *)&_input, &_output); \
		TEST_EQ(_output, _input); \
	} while (0)

static void
TestScalarArgumentsAndReturns(void)
{
	@autoreleasepool {
		InvocationSubject *subject = [InvocationSubject new];

		TEST_INTEGRAL(char, echoChar:, (char)-73);
		TEST_INTEGRAL(short, echoShort:, (short)-12345);
		TEST_INTEGRAL(int, echoInt:, -123456789);
		TEST_INTEGRAL(long, echoLong:, -INT64_C(0x123456789abc));
		TEST_INTEGRAL(bool, echoBool:, true);

		float floatInput = 13.25f;
		float floatOutput = 0.0f;
		double doubleInput = -91.5;
		double doubleOutput = 0.0;
		InvokeUnary(subject, @selector(echoFloat:), &floatInput, &floatOutput);
		InvokeUnary(subject, @selector(echoDouble:), &doubleInput, &doubleOutput);
		TEST_NEAR(floatOutput, floatInput, 0.0);
		TEST_NEAR(doubleOutput, doubleInput, 0.0);

		SEL selectorInput = @selector(echoLong:);
		SEL selectorOutput = nullptr;
		Class classInput = [InvocationSubject class];
		Class classOutput = Nil;
		void *pointerInput = (void *)(uintptr_t)UINT64_C(0x123456789abcdef0);
		void *pointerOutput = nullptr;
		InvokeUnary(subject, @selector(echoSelector:), &selectorInput, &selectorOutput);
		InvokeUnary(subject, @selector(echoClass:), &classInput, &classOutput);
		InvokeUnary(subject, @selector(echoPointer:), &pointerInput, &pointerOutput);
		TEST(selectorOutput == selectorInput);
		TEST(classOutput == classInput);
		TEST(pointerOutput == pointerInput);

		InvocationSentinel *objectInput = [InvocationSentinel new];
		__unsafe_unretained id objectOutput = nil;
		InvokeUnary(subject, @selector(echoObject:), &objectInput, &objectOutput);
		TEST(objectOutput == objectInput);

		char buffer[] = "invocation";
		char *stringInput = buffer;
		char *stringOutput = nullptr;
		InvokeUnary(subject, @selector(echoCString:), &stringInput, &stringOutput);
		TEST(stringOutput == stringInput);
		TEST_STR_EQ(stringOutput, "invocation");

		NSInvocation *blockInvocation = InvocationFor(@selector(applyBlock:value:));
		int (^block)(int) = ^int (int value) { return value * 7; };
		int value = 6;
		int result = 0;
		[blockInvocation setArgument:&block atIndex:2];
		[blockInvocation setArgument:&value atIndex:3];
		[blockInvocation invokeWithTarget:subject];
		[blockInvocation getReturnValue:&result];
		TEST_EQ_SIGNED(result, 42);

		InvocationRecordedLong = 0;
		NSInvocation *voidInvocation = InvocationFor(@selector(recordLong:));
		long recorded = 0x12345678;
		[voidInvocation setArgument:&recorded atIndex:2];
		[voidInvocation invokeWithTarget:subject];
		TEST_EQ_SIGNED(InvocationRecordedLong, recorded);
	}
}

static void
TestCompositeAndIndirectValues(void)
{
	@autoreleasepool {
		InvocationSubject *subject = [InvocationSubject new];
		C1 c1In = { 4 }, c1Out = { 0 };
		C8 c8In = { 10, 20 }, c8Out = { 0, 0 };
		C12 c12In = { 10, 20, 30 }, c12Out = { 0, 0, 0 };
		C16 c16In = { 100, 200 }, c16Out = { 0, 0 };
		I24 i24In = { 1000, 2000, 3000 }, i24Out = { 0, 0, 0 };
		I40 i40In = { 1, 2, 3, 4, 5 }, i40Out = { 0, 0, 0, 0, 0 };

		InvokeUnary(subject, @selector(bumpC1:), &c1In, &c1Out);
		InvokeUnary(subject, @selector(bumpC8:), &c8In, &c8Out);
		InvokeUnary(subject, @selector(bumpC12:), &c12In, &c12Out);
		InvokeUnary(subject, @selector(bumpC16:), &c16In, &c16Out);
		InvokeUnary(subject, @selector(bumpI24:), &i24In, &i24Out);
		InvokeUnary(subject, @selector(bumpI40:), &i40In, &i40Out);

		TEST_EQ_SIGNED(c1Out.value, 5);
		TEST(c8Out.a == 11 && c8Out.b == 22);
		TEST(c12Out.a == 11 && c12Out.b == 22 && c12Out.c == 33);
		TEST(c16Out.a == 101 && c16Out.b == 202);
		TEST(i24Out.a == 1001 && i24Out.b == 2002 && i24Out.c == 3003);
		TEST(i40Out.a == 2 && i40Out.b == 4 && i40Out.c == 6 && i40Out.d == 8 && i40Out.e == 10);

		/* INDIRECT arguments are copied for each call; a callee never receives the invocation's stored bytes. */
		NSInvocation *repeat = InvocationFor(@selector(bumpI40:));
		repeat.target = subject;
		[repeat setArgument:&i40In atIndex:2];
		for (NSUInteger iteration = 0; iteration < 32; ++iteration) {
			I40 got = { 0, 0, 0, 0, 0 };

			[repeat invoke];
			[repeat getReturnValue:&got];
			TEST(got.a == 2 && got.b == 4 && got.c == 6 && got.d == 8 && got.e == 10);
		}
	}
}

static void
TestHFAClassificationAndReturns(void)
{
	@autoreleasepool {
		InvocationSubject *subject = [InvocationSubject new];
		F1 f1In = { 1 }, f1Out = { 0 };
		F2 f2In = { 1, 2 }, f2Out = { 0, 0 };
		F3 f3In = { 1, 2, 3 }, f3Out = { 0, 0, 0 };
		F4 f4In = { 1, 2, 3, 4 }, f4Out = { 0, 0, 0, 0 };
		D1 d1In = { 1 }, d1Out = { 0 };
		D2 d2In = { 1, 2 }, d2Out = { 0, 0 };
		D3 d3In = { 1, 2, 3 }, d3Out = { 0, 0, 0 };
		D4 d4In = { 1, 2, 3, 4 }, d4Out = { 0, 0, 0, 0 };
		D3Array arrayIn = { { 2, 4, 6 } }, arrayOut = { { 0, 0, 0 } };
		NestedF3 nestedIn = { { 3, 6 }, 9 }, nestedOut = { { 0, 0 }, 0 };
		MixedFD mixedIn = { 5, 10 }, mixedOut = { 0, 0 };
		D5 fiveIn = { 1, 2, 3, 4, 5 }, fiveOut = { 0, 0, 0, 0, 0 };

		InvokeUnary(subject, @selector(bumpF1:), &f1In, &f1Out);
		InvokeUnary(subject, @selector(bumpF2:), &f2In, &f2Out);
		InvokeUnary(subject, @selector(bumpF3:), &f3In, &f3Out);
		InvokeUnary(subject, @selector(bumpF4:), &f4In, &f4Out);
		InvokeUnary(subject, @selector(bumpD1:), &d1In, &d1Out);
		InvokeUnary(subject, @selector(bumpD2:), &d2In, &d2Out);
		InvokeUnary(subject, @selector(bumpD3:), &d3In, &d3Out);
		InvokeUnary(subject, @selector(bumpD4:), &d4In, &d4Out);
		InvokeUnary(subject, @selector(bumpD3Array:), &arrayIn, &arrayOut);
		InvokeUnary(subject, @selector(bumpNestedF3:), &nestedIn, &nestedOut);
		InvokeUnary(subject, @selector(bumpMixedFD:), &mixedIn, &mixedOut);
		InvokeUnary(subject, @selector(bumpD5:), &fiveIn, &fiveOut);

		TEST_NEAR(f1Out.a, 2, 0);
		TEST_NEAR(f2Out.a + f2Out.b, 6, 0);
		TEST_NEAR(f3Out.a + f3Out.b + f3Out.c, 12, 0);
		TEST_NEAR(f4Out.a + f4Out.b + f4Out.c + f4Out.d, 20, 0);
		TEST_NEAR(d1Out.a, 2, 0);
		TEST_NEAR(d2Out.a + d2Out.b, 6, 0);
		TEST_NEAR(d3Out.a + d3Out.b + d3Out.c, 12, 0);
		TEST_NEAR(d4Out.a + d4Out.b + d4Out.c + d4Out.d, 20, 0);
		TEST_NEAR(arrayOut.values[0] + arrayOut.values[1] + arrayOut.values[2], 18, 0);
		TEST_NEAR(nestedOut.pair.a + nestedOut.pair.b + nestedOut.tail, 24, 0);
		TEST_NEAR((double)mixedOut.f + mixedOut.d, 18, 0);
		TEST_NEAR(fiveOut.a + fiveOut.b + fiveOut.c + fiveOut.d + fiveOut.e, 30, 0);
	}
}

static void
TestRegisterExhaustion(void)
{
	@autoreleasepool {
		InvocationSubject *subject = [InvocationSubject new];

		/* Five scalars leave one GP register. The two-register composite spills and closes the bank. */
		NSInvocation *gp = InvocationFor(@selector(gpSlamA:b:c:d:e:pair:tail:));
		long gpValues[5] = { 1, 2, 3, 4, 5 };
		C16 pair = { 6, 7 };
		long tail = 8;
		long gpResult = 0;
		for (NSUInteger index = 0; index < 5; ++index)
			[gp setArgument:&gpValues[index] atIndex:index + 2];
		[gp setArgument:&pair atIndex:7];
		[gp setArgument:&tail atIndex:8];
		[gp invokeWithTarget:subject];
		[gp getReturnValue:&gpResult];
		TEST_EQ_SIGNED(gpResult, 204);

		/* Seven doubles leave one SIMD register. The two-member HFA and following scalar both spill. */
		NSInvocation *fp = InvocationFor(@selector(fpSlamA:b:c:d:e:f:g:pair:tail:));
		double fpValues[7] = { 1, 2, 3, 4, 5, 6, 7 };
		D2 doublePair = { 8, 9 };
		double doubleTail = 10;
		double fpResult = 0;
		for (NSUInteger index = 0; index < 7; ++index)
			[fp setArgument:&fpValues[index] atIndex:index + 2];
		[fp setArgument:&doublePair atIndex:9];
		[fp setArgument:&doubleTail atIndex:10];
		[fp invokeWithTarget:subject];
		[fp getReturnValue:&fpResult];
		TEST_NEAR(fpResult, 385, 0);

		/* Six scalars fill x2-x7, so the by-reference INDIRECT pointer and the trailing scalar live on the stack. */
		NSInvocation *indirect = InvocationFor(@selector(indirectOnStackA:b:c:d:e:f:large:tail:));
		long indirectValues[6] = { 1, 2, 3, 4, 5, 6 };
		I24 large = { 7, 8, 9 };
		long indirectTail = 10;
		long indirectResult = 0;
		for (NSUInteger index = 0; index < 6; ++index)
			[indirect setArgument:&indirectValues[index] atIndex:index + 2];
		[indirect setArgument:&large atIndex:8];
		[indirect setArgument:&indirectTail atIndex:9];
		[indirect invokeWithTarget:subject];
		[indirect getReturnValue:&indirectResult];
		TEST_EQ_SIGNED(indirectResult, 385);

		/* Both independent banks fill and then spill in one call. */
		NSInvocation *mixed = InvocationFor(@selector(mixedOverflowL0:d0:l1:d1:l2:d2:l3:d3:
			l4:d4:l5:d5:l6:d6:l7:d7:));
		double mixedResult = 0;
		for (NSUInteger index = 0; index < 8; ++index) {
			long integer = (long)index + 1;
			double floating = (double)(index + 1) * 10;

			[mixed setArgument:&integer atIndex:2 + index * 2];
			[mixed setArgument:&floating atIndex:3 + index * 2];
		}
		[mixed invokeWithTarget:subject];
		[mixed getReturnValue:&mixedResult];
		TEST_NEAR(mixedResult, 2244, 0);
	}
}

static void
TestInvocationEntryPointsAndNil(void)
{
	@autoreleasepool {
		InvocationSubject *first = [InvocationSubject new];
		InvocationSubject *second = [InvocationSubject new];
		NSInvocation *invocation = InvocationFor(@selector(echoLong:));
		long value = 91;
		long result = 0;
		IMP implementation = class_getMethodImplementation([InvocationSubject class], @selector(echoLong:));

		[invocation setArgument:&value atIndex:2];
		invocation.target = first;
		[invocation invoke];
		[invocation getReturnValue:&result];
		TEST_EQ_SIGNED(result, value);

		value = 92;
		[invocation setArgument:&value atIndex:2];
		[invocation invokeWithTarget:second];
		[invocation getReturnValue:&result];
		TEST(invocation.target == second);
		TEST_EQ_SIGNED(result, value);

		value = 93;
		[invocation setArgument:&value atIndex:2];
		[invocation invokeUsingIMP:implementation];
		[invocation getReturnValue:&result];
		TEST_EQ_SIGNED(result, value);

		/* All return classifications are zeroed for nil messaging. */
		long primedLong = -1;
		[invocation setReturnValue:&primedLong];
		invocation.target = nil;
		[invocation invoke];
		[invocation getReturnValue:&result];
		TEST_EQ_SIGNED(result, 0);

		NSInvocation *hfa = InvocationFor(@selector(bumpD4:));
		D4 primedHFA = { 1, 2, 3, 4 };
		D4 zeroHFA = { 9, 9, 9, 9 };
		D4 const expectedZeroHFA = { 0, 0, 0, 0 };
		hfa.target = nil;
		[hfa setReturnValue:&primedHFA];
		[hfa invokeUsingIMP:class_getMethodImplementation([InvocationSubject class], @selector(bumpD4:))];
		[hfa getReturnValue:&zeroHFA];
		TEST_BYTES_EQ(&zeroHFA, &expectedZeroHFA, sizeof(zeroHFA));

		NSInvocation *indirect = InvocationFor(@selector(bumpI40:));
		I40 primedIndirect = { 1, 2, 3, 4, 5 };
		I40 zeroIndirect = { 9, 9, 9, 9, 9 };
		I40 const expectedZeroIndirect = { 0, 0, 0, 0, 0 };
		[indirect setReturnValue:&primedIndirect];
		[indirect invokeWithTarget:nil];
		[indirect getReturnValue:&zeroIndirect];
		TEST_BYTES_EQ(&zeroIndirect, &expectedZeroIndirect, sizeof(zeroIndirect));
	}
}

static void
TestNilTargetReplacement(void)
{
	SEL const selectors[] = { @selector(echoLong:), @selector(bumpD4:), @selector(bumpI40:),
		@selector(recordLong:) };

	for (unsigned retained = 0; retained < 2; ++retained)
		for (NSUInteger index = 0; index < sizeof(selectors) / sizeof(selectors[0]); ++index)
			@autoreleasepool {
				InvocationSubject *subject = [InvocationSubject new];
				NSInvocation *invocation = InvocationFor(selectors[index]);
				unsigned char result[sizeof(I40)];
				unsigned char const zero[sizeof(I40)] = { 0 };
				NSUInteger const size = invocation.methodSignature.methodReturnLength;
				__unsafe_unretained id storedTarget = nil;

				invocation.target = subject;
				if (retained != 0)
					[invocation retainArguments];
				TEST(size <= sizeof(result));
				/* Prime the result before each call, including repeated nil and plain invocation. */
				for (unsigned step = 0; step < 3; ++step) {
					memset(result, 0x5a, sizeof(result));
					[invocation setReturnValue:result];
					InvocationRecordedLong = 123;
					if (step < 2)
						[invocation invokeWithTarget:nil];
					else
						[invocation invoke];
					TEST(invocation.target == nil);
					[invocation getArgument:&storedTarget atIndex:0];
					TEST(storedTarget == nil);
					[invocation getReturnValue:result];
					TEST_BYTES_EQ(result, zero, size);
					TEST_EQ_SIGNED(InvocationRecordedLong, 123);
				}
				/* A later nonnil target reinstalls the receiver and performs the call. */
				[invocation invokeWithTarget:subject];
				TEST(invocation.target == subject);
				if (selectors[index] == @selector(recordLong:))
					TEST_EQ_SIGNED(InvocationRecordedLong, 0);
			}
}

static void
TestForwarding(void)
{
	@autoreleasepool {
		InvocationSubject *subject = [InvocationSubject new];
		InvocationSubject *proxy = (InvocationSubject *)[InvocationProxy proxyWithBacking:subject];
		InvocationSubject *fast = (InvocationSubject *)[InvocationFastProxy proxyWithBacking:subject];
		NSUInteger const before = InvocationForwardCount;

		TEST_EQ_SIGNED([proxy echoLong:123], 123);
		TEST_NEAR([proxy echoFloat:2.5f], 2.5f, 0);
		TEST_NEAR([proxy echoDouble:3.5], 3.5, 0);

		C1 c1 = [proxy bumpC1:(C1){ 4 }];
		C8 c8 = [proxy bumpC8:(C8){ 1, 2 }];
		C12 c12 = [proxy bumpC12:(C12){ 1, 2, 3 }];
		C16 c16 = [proxy bumpC16:(C16){ 1, 2 }];
		TEST(c1.value == 5);
		TEST(c8.a == 2 && c8.b == 4);
		TEST(c12.a == 2 && c12.b == 4 && c12.c == 6);
		TEST(c16.a == 2 && c16.b == 4);

		F1 f1 = [proxy bumpF1:(F1){ 1 }];
		F2 f2 = [proxy bumpF2:(F2){ 1, 2 }];
		F3 f3 = [proxy bumpF3:(F3){ 1, 2, 3 }];
		F4 f4 = [proxy bumpF4:(F4){ 1, 2, 3, 4 }];
		D1 d1 = [proxy bumpD1:(D1){ 1 }];
		D2 d2 = [proxy bumpD2:(D2){ 1, 2 }];
		D3 d3 = [proxy bumpD3:(D3){ 1, 2, 3 }];
		D4 d4 = [proxy bumpD4:(D4){ 1, 2, 3, 4 }];
		TEST_NEAR(f1.a, 2, 0);
		TEST_NEAR(f2.a + f2.b, 6, 0);
		TEST_NEAR(f3.a + f3.b + f3.c, 12, 0);
		TEST_NEAR(f4.a + f4.b + f4.c + f4.d, 20, 0);
		TEST_NEAR(d1.a, 2, 0);
		TEST_NEAR(d2.a + d2.b, 6, 0);
		TEST_NEAR(d3.a + d3.b + d3.c, 12, 0);
		TEST_NEAR(d4.a + d4.b + d4.c + d4.d, 20, 0);

		D3Array array = [proxy bumpD3Array:(D3Array){ { 1, 2, 3 } }];
		NestedF3 nested = [proxy bumpNestedF3:(NestedF3){ { 1, 2 }, 3 }];
		MixedFD mixed = [proxy bumpMixedFD:(MixedFD){ 1, 2 }];
		D5 five = [proxy bumpD5:(D5){ 1, 2, 3, 4, 5 }];
		I24 i24 = [proxy bumpI24:(I24){ 1, 2, 3 }];
		I40 i40 = [proxy bumpI40:(I40){ 1, 2, 3, 4, 5 }];
		TEST_NEAR(array.values[0] + array.values[1] + array.values[2], 12, 0);
		TEST_NEAR(nested.pair.a + nested.pair.b + nested.tail, 12, 0);
		TEST_NEAR((double)mixed.f + mixed.d, 6, 0);
		TEST_NEAR(five.a + five.b + five.c + five.d + five.e, 30, 0);
		TEST(i24.a == 2 && i24.b == 4 && i24.c == 6);
		TEST(i40.a == 2 && i40.b == 4 && i40.c == 6 && i40.d == 8 && i40.e == 10);

		long const forwardedGP = [proxy gpSlamA:1 b:2 c:3 d:4 e:5 pair:(C16){ 6, 7 } tail:8];
		double const forwardedFP = [proxy fpSlamA:1 b:2 c:3 d:4 e:5 f:6 g:7
			pair:(D2){ 8, 9 } tail:10];
		long const forwardedIndirect = [proxy indirectOnStackA:1 b:2 c:3 d:4 e:5 f:6
			large:(I24){ 7, 8, 9 } tail:10];
		TEST_EQ_SIGNED(forwardedGP, 204);
		TEST_NEAR(forwardedFP, 385, 0);
		TEST_EQ_SIGNED(forwardedIndirect, 385);

		InvocationRecordedLong = 0;
		[proxy recordLong:777];
		TEST_EQ_SIGNED(InvocationRecordedLong, 777);
		TEST_EQ_UNSIGNED(InvocationForwardCount - before, 25);

		TEST_EQ_SIGNED([fast echoLong:321], 321);
		D4 fastHFA = [fast bumpD4:(D4){ 1, 1, 1, 1 }];
		I40 fastIndirect = [fast bumpI40:(I40){ 1, 1, 1, 1, 1 }];
		TEST_NEAR(fastHFA.a + fastHFA.b + fastHFA.c + fastHFA.d, 14, 0);
		TEST(fastIndirect.a == 2 && fastIndirect.b == 3 && fastIndirect.c == 4 &&
			fastIndirect.d == 5 && fastIndirect.e == 6);
	}
}

static void
TestDeferredLookupAndResolution(void)
{
	@autoreleasepool {
		InvocationSubject *subject = [InvocationSubject new];
		InvocationSubject *proxy = (InvocationSubject *)[InvocationProxy proxyWithBacking:subject];
		IMP implementation = class_getMethodImplementation([InvocationProxy class], @selector(echoLong:));

		TEST(implementation != nullptr);
		TEST_EQ_SIGNED(((LongCall)implementation)(proxy, @selector(echoLong:), 47), 47);

		InvocationResolver *resolver = [InvocationResolver new];
		implementation = class_getMethodImplementation([InvocationResolver class], @selector(resolvedTriple:));
		TEST(implementation != nullptr);
		TEST_EQ_SIGNED(((IntCall)implementation)(resolver, @selector(resolvedTriple:), 9), 27);
		TEST([InvocationResolver instancesRespondToSelector:@selector(resolvedTriple:)]);

		Class classReceiver = [InvocationClassResolver class];
		Class metaClass = object_getClass(classReceiver);
		implementation = class_getMethodImplementation(metaClass, @selector(resolvedQuad:));
		TEST(implementation != nullptr);
		TEST_EQ_SIGNED(((IntCall)implementation)(classReceiver, @selector(resolvedQuad:), 9), 36);
		TEST([InvocationClassResolver respondsToSelector:@selector(resolvedQuad:)]);
	}
}

static void
TestRetainedArguments(void)
{
	@autoreleasepool {
		InvocationSubject *subject = [InvocationSubject new];
		int const baseline = InvocationSentinelLiveCount;
		NSInvocation *invocation = InvocationFor(@selector(echoObject:));

		invocation.target = subject;
		@autoreleasepool {
			InvocationSentinel *first = [InvocationSentinel new];

			[invocation setArgument:&first atIndex:2];
			[invocation retainArguments];
			[invocation retainArguments];
			first = nil;
		}
		TEST(invocation.argumentsRetained);
		TEST_EQ_SIGNED(InvocationSentinelLiveCount, baseline + 1);

		@autoreleasepool {
			InvocationSentinel *second = [InvocationSentinel new];

			[invocation setArgument:&second atIndex:2];
			second = nil;
		}
		TEST_EQ_SIGNED(InvocationSentinelLiveCount, baseline + 1);

		[invocation invoke];
		__unsafe_unretained id returned = nil;
		[invocation getReturnValue:&returned];
		TEST(returned != nil);
		TEST_EQ_SIGNED(InvocationSentinelLiveCount, baseline + 1);

		__unsafe_unretained id nilObject = nil;
		[invocation setReturnValue:&nilObject];
		[invocation setArgument:&nilObject atIndex:2];
		TEST_EQ_SIGNED(InvocationSentinelLiveCount, baseline);
	}

	@autoreleasepool {
		InvocationSubject *subject = [InvocationSubject new];
		NSInvocation *invocation = InvocationFor(@selector(echoCString:));
		char firstBuffer[] = "first";
		char secondBuffer[] = "second";
		char *argument = firstBuffer;
		char *stored = nullptr;
		char *returned = nullptr;

		invocation.target = subject;
		[invocation setArgument:&argument atIndex:2];
		[invocation retainArguments];
		firstBuffer[0] = 'X';
		[invocation getArgument:&stored atIndex:2];
		TEST_STR_EQ(stored, "first");

		argument = secondBuffer;
		[invocation setArgument:&argument atIndex:2];
		secondBuffer[0] = 'X';
		[invocation getArgument:&stored atIndex:2];
		TEST_STR_EQ(stored, "second");
		[invocation invoke];
		[invocation getReturnValue:&returned];
		TEST_STR_EQ(returned, "second");

		/* A null C string is a valid pointer value and must remain null while retained. */
		argument = nullptr;
		[invocation setArgument:&argument atIndex:2];
		[invocation getArgument:&stored atIndex:2];
		TEST(stored == nullptr);
		[invocation invoke];
		[invocation getReturnValue:&returned];
		TEST(returned == nullptr);
	}

	@autoreleasepool {
		InvocationSubject *subject = [InvocationSubject new];
		NSInvocation *invocation = InvocationFor(@selector(applyBlock:value:));
		int (^block)(int) = ^int (int value) { return value + 1000; };
		int value = 24;
		int result = 0;

		invocation.target = subject;
		[invocation setArgument:&block atIndex:2];
		[invocation setArgument:&value atIndex:3];
		[invocation retainArguments];
		block = nil;
		[invocation invoke];
		[invocation getReturnValue:&result];
		TEST_EQ_SIGNED(result, 1024);
	}
}

static void
TestMemoryStress(void)
{
	int const baseline = InvocationSentinelLiveCount;

	for (NSUInteger iteration = 0; iteration < 4096; ++iteration)
		@autoreleasepool {
			InvocationSubject *subject = [InvocationSubject new];
			NSInvocation *invocation = InvocationFor(@selector(echoObject:));
			InvocationSentinel *sentinel = [InvocationSentinel new];
			__unsafe_unretained id returned = nil;

			invocation.target = subject;
			[invocation setArgument:&sentinel atIndex:2];
			[invocation retainArguments];
			[invocation invoke];
			[invocation getReturnValue:&returned];
			if (returned != sentinel)
				TEST_MSG(false, "retained object was corrupted during stress test");
		}

	TEST_EQ_SIGNED(InvocationSentinelLiveCount, baseline);
}

int
main(void)
{
	TestScalarArgumentsAndReturns();
	TestCompositeAndIndirectValues();
	TestHFAClassificationAndReturns();
	TestRegisterExhaustion();
	TestInvocationEntryPointsAndNil();
	TestNilTargetReplacement();
	TestForwarding();
	TestDeferredLookupAndResolution();
	TestRetainedArguments();
	TestMemoryStress();

	return TestFinish();
}

#pragma clang diagnostic pop

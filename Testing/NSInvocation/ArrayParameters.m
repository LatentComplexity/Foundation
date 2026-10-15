/* Compiler-declared array parameters: pointer identity, pointee effects, ownership, and aggregate returns. */
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSObject.h>
#import "Test.h"

#include <stdlib.h>
#include <string.h>

typedef struct { double values[4]; } FourDoubles;
typedef struct { long values[5]; } FiveLongs;

@interface ArraySubject : NSObject
- (void)copy:(float[4])input output:(float *)output;
- (void)increment:(inout float[4])input;
- (float)matrix:(float[2][4])input;
- (void *)characters:(char[4])input;
- (FourDoubles)combine:(float[4])input structure:(FourDoubles)value;
- (FiveLongs)largeReturn:(float[4])input tail:(long)tail;
@end

@implementation ArraySubject
- (void)copy:(float[4])input output:(float *)output
{
	memcpy(output, input, 4 * sizeof(float));
}
- (void)increment:(inout float[4])input
{
	for (NSUInteger i = 0; i < 4; ++i)
		input[i] += (float)(i + 1);
}
- (float)matrix:(float[2][4])input
{
	return input[0][0] + 2 * input[0][3] + 4 * input[1][0] + 8 * input[1][3];
}
- (void *)characters:(char[4])input
{
	input[3] = 'Z';
	return input;
}
- (FourDoubles)combine:(float[4])input structure:(FourDoubles)value
{
	for (NSUInteger i = 0; i < 4; ++i)
		value.values[i] += (double)input[3 - i];
	return value;
}
- (FiveLongs)largeReturn:(float[4])input tail:(long)tail
{
	return (FiveLongs){{(long)input[3], (long)input[2], (long)input[1], (long)input[0], tail}};
}
@end

static NSUInteger ForwardCount;

@interface ArrayProxy : NSObject
+ (instancetype)proxyWithSubject:(ArraySubject *)subject;
@end
@implementation ArrayProxy {
	ArraySubject *_subject;
}
+ (instancetype)proxyWithSubject:(ArraySubject *)subject
{
	ArrayProxy *proxy = [self new];
	proxy->_subject = subject;
	return proxy;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	return [_subject methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
	++ForwardCount;
	[invocation invokeWithTarget:_subject];
}
@end

static NSInvocation *
Invocation(ArraySubject *subject, SEL selector)
{
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
		[subject methodSignatureForSelector:selector]];
	invocation.target = subject;
	invocation.selector = selector;
	return invocation;
}

static void
TestCopyAndMutation(ArraySubject *subject, ArraySubject *proxy)
{
	float input[4] = { 1.25f, -2.5f, 3.75f, 4.5f };
	float direct[4] = {}, output[4] = {};
	float *pointer = input;
	float *destination = output;
	NSInvocation *invocation = Invocation(subject, @selector(copy:output:));

	TEST_STR_EQ([invocation.methodSignature getArgumentTypeAtIndex:2], "[4f]");
	TEST_EQ_UNSIGNED(invocation.methodSignature.frameLength, 4 * sizeof(void *));
	[subject copy:input output:direct];
	/* Exact allocations make ASan diagnose either an oversized read or write of the argument slot. */
	float **sourceSlot = malloc(sizeof(pointer));
	float **resultSlot = malloc(sizeof(pointer));
	TEST(sourceSlot != nullptr && resultSlot != nullptr);
	if (sourceSlot == nullptr || resultSlot == nullptr) {
		free(sourceSlot);
		free(resultSlot);
		return;
	}
	*sourceSlot = pointer;
	*resultSlot = pointer;
	[invocation getArgument:resultSlot atIndex:2];
	TEST(*resultSlot == nullptr);
	[invocation setArgument:sourceSlot atIndex:2];
	[invocation getArgument:resultSlot atIndex:2];
	TEST(*resultSlot == pointer);
	free(sourceSlot);
	free(resultSlot);
	[invocation setArgument:&destination atIndex:3];
	[invocation invoke];
	TEST_BYTES_EQ(output, direct, sizeof(output));

	/* The stored value is the pointer: later changes to its pointee must be visible on a repeated invocation. */
	input[2] = 29.5f;
	[invocation retainArguments];
	[invocation invoke];
	TEST_BYTES_EQ(output, input, sizeof(output));
	float forwarded[4] = {};
	[proxy copy:input output:forwarded];
	TEST_BYTES_EQ(forwarded, input, sizeof(input));

	NSInvocation *mutation = Invocation(subject, @selector(increment:));
	[mutation setArgument:&pointer atIndex:2];
	[mutation retainArguments];
	memcpy(direct, input, sizeof(input));
	[subject increment:direct];
	[mutation invoke];
	TEST_BYTES_EQ(input, direct, sizeof(input));
	[subject increment:direct];
	[proxy increment:input];
	TEST_BYTES_EQ(input, direct, sizeof(input));

	/* Replacing an array pointer after retainArguments must preserve its ordinary pointer ownership. */
	float replacement[4] = { 31, 37, 41, 43 };
	pointer = replacement;
	[mutation setArgument:&pointer atIndex:2];
	[mutation invoke];
	float expected[4] = { 32, 39, 44, 47 };
	TEST_BYTES_EQ(replacement, expected, sizeof(expected));
}

static void
TestMatrixAndCharacterArrays(ArraySubject *subject, ArraySubject *proxy)
{
	float matrix[2][4] = {{1, 2, 3, 4}, {11, 12, 13, 14}};
	float (*rows)[4] = matrix;
	float result = 0;
	NSInvocation *invocation = Invocation(subject, @selector(matrix:));
	[invocation setArgument:&rows atIndex:2];
	[invocation invoke];
	[invocation getReturnValue:&result];
	TEST_NEAR(result, [subject matrix:matrix], 0);
	TEST_NEAR([proxy matrix:matrix], 165, 0);

	/* A char-array parameter is a raw pointer, not an instruction to strdup a C string. No terminator exists. */
	char characters[4] = {'A', 'B', 'C', 'D'};
	char *pointer = characters;
	char *got = nullptr;
	NSInvocation *chars = Invocation(subject, @selector(characters:));
	TEST_STR_EQ([chars.methodSignature getArgumentTypeAtIndex:2], @encode(char[4]));
	[chars setArgument:&pointer atIndex:2];
	[chars retainArguments];
	[chars getArgument:&got atIndex:2];
	TEST(got == pointer);
	[chars invoke];
	TEST_EQ(characters[3], 'Z');
	characters[3] = 'D';
	TEST([proxy characters:characters] == pointer);
	TEST_EQ(characters[3], 'Z');
}

static void
TestAggregateReturns(ArraySubject *subject, ArraySubject *proxy)
{
	float input[4] = { 1, 2, 3, 4 };
	float *pointer = input;
	FourDoubles structure = {{11.5, 13.25, 17.75, 19.5}};
	FourDoubles expected = [subject combine:input structure:structure];
	FourDoubles result = {};
	NSInvocation *invocation = Invocation(subject, @selector(combine:structure:));
	[invocation setArgument:&pointer atIndex:2];
	[invocation setArgument:&structure atIndex:3];
	[invocation invoke];
	[invocation getReturnValue:&result];
	TEST_BYTES_EQ(result.values, expected.values, sizeof(expected.values));
	result = [proxy combine:input structure:structure];
	TEST_BYTES_EQ(result.values, expected.values, sizeof(expected.values));

	long tail = -3701;
	FiveLongs largeExpected = [subject largeReturn:input tail:tail];
	FiveLongs largeResult = {};
	invocation = Invocation(subject, @selector(largeReturn:tail:));
	[invocation setArgument:&pointer atIndex:2];
	[invocation setArgument:&tail atIndex:3];
	[invocation invoke];
	[invocation getReturnValue:&largeResult];
	TEST_BYTES_EQ(largeResult.values, largeExpected.values, sizeof(largeExpected.values));
	largeResult = [proxy largeReturn:input tail:tail];
	TEST_BYTES_EQ(largeResult.values, largeExpected.values, sizeof(largeExpected.values));
}

int
main(void)
{
	@autoreleasepool {
		ArraySubject *subject = [ArraySubject new];
		ArraySubject *proxy = (ArraySubject *)[ArrayProxy proxyWithSubject:subject];
		TestCopyAndMutation(subject, proxy);
		TestMatrixAndCharacterArrays(subject, proxy);
		TestAggregateReturns(subject, proxy);
		TEST_EQ_UNSIGNED(ForwardCount, 6);
	}
	return TestFinish();
}

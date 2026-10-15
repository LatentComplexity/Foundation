#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSObject.h>
#import "Test.h"

#include <stdio.h>
#include <string.h>

static void
TestByteSlots(void)
{
	struct Fixture { char const *type; NSUInteger size; } const fixtures[] = {
		{"c", 1}, {"s", 2}, {"i", 4}, {"q", 8}, {"f", 4}, {"d", 8}, {"^v", sizeof(void *)},
		{"{Pair=qq}", 16}, {"{Triple=qqq}", 24}, {"{Four=dddd}", 32}
	};
	for (NSUInteger f = 0; f < sizeof(fixtures) / sizeof(fixtures[0]); ++f)
		@autoreleasepool {
			char encoding[128];
			snprintf(encoding, sizeof(encoding), "%s@:%s", fixtures[f].type, fixtures[f].type);
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
				[NSMethodSignature signatureWithObjCTypes:encoding]];
			alignas(16) unsigned char input[64], output[64];
			for (NSUInteger i = 0; i < sizeof(input); ++i) input[i] = (unsigned char)(i + 31);
			for (NSUInteger offset = 1; offset < 16; ++offset) {
				[invocation setArgument:input + offset atIndex:2];
				[invocation setReturnValue:input + offset];
				for (unsigned slot = 0; slot < 2; ++slot) {
					memset(output, 0xa5, sizeof(output));
					if (slot == 0) [invocation getArgument:output + offset atIndex:2];
					else [invocation getReturnValue:output + offset];
					TEST_BYTES_EQ(output + offset, input + offset, fixtures[f].size);
					for (NSUInteger i = 0; i < sizeof(output); ++i)
						if (i < offset || i >= offset + fixtures[f].size) TEST_EQ_UNSIGNED(output[i], 0xa5);
				}
			}
		}
}

static void
TestReceiverAndSelector(void)
{
	@autoreleasepool {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
			[NSMethodSignature signatureWithObjCTypes:"v@:"]];
		__attribute__((objc_precise_lifetime)) NSObject *object = [NSObject new];
		id __unsafe_unretained receiver = object;
		SEL selector = @selector(description);
		alignas(16) unsigned char input[32], output[32];
		for (NSUInteger index = 0; index < 2; ++index)
			for (NSUInteger offset = 1; offset < 16; ++offset) {
				if (index == 0) memcpy(input + offset, &receiver, sizeof(receiver));
				else memcpy(input + offset, &selector, sizeof(selector));
				[invocation setArgument:input + offset atIndex:index];
				memset(output, 0xa5, sizeof(output));
				[invocation getArgument:output + offset atIndex:index];
				TEST_BYTES_EQ(output + offset, input + offset, sizeof(void *));
				for (NSUInteger i = 0; i < sizeof(output); ++i)
					if (i < offset || i >= offset + sizeof(void *)) TEST_EQ_UNSIGNED(output[i], 0xa5);
			}
	}
}

int
main(void)
{
	TestByteSlots();
	TestReceiverAndSelector();
	return TestFinish();
}

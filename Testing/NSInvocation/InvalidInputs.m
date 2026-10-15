#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSObject.h>
#import "Test.h"

#import <objc/runtime.h>

#include <stdint.h>

typedef struct {
	double a;
	double b;
	double c;
	double d;
} FourDouble;

@interface Subject : NSObject
- (long)twice:(long)value;
- (FourDouble)quad:(FourDouble)value;
@end

@implementation Subject
- (long)twice:(long)value
{
	return value * 2;
}
- (FourDouble)quad:(FourDouble)value
{
	return value;
}
@end

@interface SignatureOnlyProxy : NSObject
@end

@implementation SignatureOnlyProxy
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];

	return signature != nil ? signature : [Subject instanceMethodSignatureForSelector:aSelector];
}
@end

static NSInvocation *
InvocationFor(SEL selector)
{
	NSMethodSignature *signature = [Subject instanceMethodSignatureForSelector:selector];
	NSInvocation *invocation;

	invocation = [NSInvocation invocationWithMethodSignature:signature];

	invocation.selector = selector;
	return invocation;
}

static void
TestInvalidConstruction(void)
{
	@autoreleasepool {
		NSMethodSignature *nilSignature = nil;

		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[NSInvocation invocationWithMethodSignature:nilSignature]);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-messaging-id"
		TEST_THROWS_NAME(NSUnavailableMethodUsageException,
			(void)[(id)[NSInvocation alloc] init]);
#pragma clang diagnostic pop
	}
}

static void
TestArgumentValidation(void)
{
	@autoreleasepool {
		NSInvocation *invocation = InvocationFor(@selector(twice:));
		NSUInteger const count = invocation.methodSignature.numberOfArguments;
		long value = 1;
		void *nullLocation = nullptr;

		TEST_THROWS_NAME(NSInvalidArgumentException,
			[invocation setArgument:nullLocation atIndex:0]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[invocation setArgument:nullLocation atIndex:1]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[invocation setArgument:nullLocation atIndex:2]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[invocation getArgument:nullLocation atIndex:0]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[invocation getArgument:nullLocation atIndex:1]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[invocation getArgument:nullLocation atIndex:2]);

		TEST_THROWS_NAME(NSRangeException,
			[invocation setArgument:&value atIndex:count]);
		TEST_THROWS_NAME(NSRangeException,
			[invocation setArgument:&value atIndex:NSUIntegerMax]);
		TEST_THROWS_NAME(NSRangeException,
			[invocation getArgument:&value atIndex:count]);
		TEST_THROWS_NAME(NSRangeException,
			[invocation getArgument:&value atIndex:NSUIntegerMax]);
	}
}

static void
TestReturnValidation(void)
{
	@autoreleasepool {
		NSInvocation *valueInvocation = InvocationFor(@selector(twice:));
		NSInvocation *voidInvocation = [NSInvocation invocationWithMethodSignature:
			[NSMethodSignature signatureWithObjCTypes:"v@:"]];
		void *nullLocation = nullptr;

		TEST_THROWS_NAME(NSInvalidArgumentException,
			[valueInvocation setReturnValue:nullLocation]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[valueInvocation getReturnValue:nullLocation]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[voidInvocation setReturnValue:nullLocation]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[voidInvocation getReturnValue:nullLocation]);
	}
}

static void
TestInvocationValidation(void)
{
	@autoreleasepool {
		Subject *subject = [Subject new];
		NSMethodSignature *signature = [Subject instanceMethodSignatureForSelector:@selector(twice:)];
		NSInvocation *withoutSelector = [NSInvocation invocationWithMethodSignature:signature];
		NSInvocation *invocation = InvocationFor(@selector(twice:));
		IMP implementation = class_getMethodImplementation([Subject class], @selector(twice:));
		IMP nullImplementation = nullptr;

		TEST_THROWS_NAME(NSInvalidArgumentException, [withoutSelector invoke]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [withoutSelector invokeWithTarget:subject]);
		withoutSelector.target = subject;
		TEST_THROWS_NAME(NSInvalidArgumentException, [withoutSelector invokeWithTarget:nil]);
		TEST(withoutSelector.target == subject);
		TEST_THROWS_NAME(NSInvalidArgumentException, [withoutSelector invokeUsingIMP:implementation]);

		invocation.target = subject;
		TEST_THROWS_NAME(NSInvalidArgumentException, [invocation invokeUsingIMP:nullImplementation]);
		invocation.target = nil;
		TEST_THROWS_NAME(NSInvalidArgumentException, [invocation invokeUsingIMP:nullImplementation]);
	}
}

static void
TestForwardingFailures(void)
{
	@autoreleasepool {
		Subject *plain = (Subject *)[NSObject new];
		Subject *signatureOnly = (Subject *)[SignatureOnlyProxy new];

		/* No method signature: the forwarding hook rejects the message before building an invocation. */
		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[plain twice:1]);

		/* A signature without -forwardInvocation: reaches NSObject's rejecting implementation. */
		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[signatureOnly twice:1]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[signatureOnly quad:(FourDouble){ 1, 2, 3, 4 }]);
	}
}

int
main(void)
{
	TestInvalidConstruction();
	TestArgumentValidation();
	TestReturnValidation();
	TestInvocationValidation();
	TestForwardingFailures();

	return TestFinish();
}

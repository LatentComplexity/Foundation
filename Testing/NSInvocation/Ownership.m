#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSObject.h>
#import <objc/objc-arc.h>
#import <objc/runtime.h>
#import "Test.h"

#include <stdio.h>
#include <string.h>

static int LiveObjects;

@interface OwnershipObject : NSObject
@property (nonatomic) int value;
- (id)objectResult;
@end
@implementation OwnershipObject
@synthesize value = _value;
- (instancetype)init
{
	self = [super init];
	if (self != nil) ++LiveObjects;
	return self;
}
- (void)dealloc { --LiveObjects; }
- (id)objectResult { return self; }
@end

/* These are real compiler declarations, independently of the synthetic qualifier matrix below. */
@interface QualifierSubject : NSObject
- (void)plain:(id)value;
- (void)input:(in id)value;
- (void)output:(out id)value;
- (void)both:(inout id)value;
- (void)copied:(bycopy id)value;
- (void)reference:(byref id)value;
- (void)text:(const char *)value;
@end
@implementation QualifierSubject
- (void)plain:(id)value { (void)value; }
- (void)input:(in id)value { (void)value; }
- (void)output:(out id)value { (void)value; }
- (void)both:(inout id)value { (void)value; }
- (void)copied:(bycopy id)value { (void)value; }
- (void)reference:(byref id)value { (void)value; }
- (void)text:(const char *)value { (void)value; }
@end

static NSInvocation *
NewInvocation(char const *qualifiers, char const *type, bool returnSlot)
{
	char encoding[128];
	if (returnSlot)
		snprintf(encoding, sizeof(encoding), "%s%s@:", qualifiers, type);
	else
		snprintf(encoding, sizeof(encoding), "v@:%s%s", qualifiers, type);
	return [NSInvocation invocationWithMethodSignature:[NSMethodSignature signatureWithObjCTypes:encoding]];
}

static void
Put(NSInvocation *invocation, bool returnSlot, void *value)
{
	if (returnSlot) [invocation setReturnValue:value];
	else [invocation setArgument:value atIndex:2];
}

static void
Get(NSInvocation *invocation, bool returnSlot, void *value)
{
	if (returnSlot) [invocation getReturnValue:value];
	else [invocation getArgument:value atIndex:2];
}

static void
TestNilTargetReleasesStoredObjects(void)
{
	for (unsigned alias = 0; alias < 2; ++alias)
		@autoreleasepool {
			NSInvocation *invocation = NewInvocation("", "@", true);
			@autoreleasepool {
				OwnershipObject *target = [OwnershipObject new];
				OwnershipObject *result = alias != 0 ? target : [OwnershipObject new];

				invocation.selector = @selector(objectResult);
				invocation.target = target;
				[invocation setReturnValue:&result];
				[invocation retainArguments];
			}
			TEST_EQ(LiveObjects, alias != 0 ? 1 : 2);
			[invocation invokeWithTarget:nil];
			TEST(invocation.target == nil);
			TEST_EQ(LiveObjects, 0);
			id __unsafe_unretained result = nil;
			[invocation getReturnValue:&result];
			TEST(result == nil);
			[invocation invoke];
			[invocation getReturnValue:&result];
			TEST(result == nil);
			TEST_EQ(LiveObjects, 0);
		}
	TEST_EQ(LiveObjects, 0);
}

static void
TestCompilerQualifiers(void)
{
	SEL const selectors[] = {@selector(plain:), @selector(input:), @selector(output:), @selector(both:),
		@selector(copied:), @selector(reference:), @selector(text:)};
	char const *const expected[] = {"@", "n@", "o@", "N@", "O@", "R@", "r*"};
	TEST_STR_EQ(@encode(id), "@");
	for (NSUInteger i = 0; i < sizeof(selectors) / sizeof(selectors[0]); ++i)
		@autoreleasepool {
			Method method = class_getInstanceMethod([QualifierSubject class], selectors[i]);
			NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
			TEST_STR_EQ([signature getArgumentTypeAtIndex:2], expected[i]);
			printf("@encode(id)=%s; %s argument=%s\n", @encode(id), sel_getName(selectors[i]),
				[signature getArgumentTypeAtIndex:2]);
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
			if (i == 6) {
				char buffer[] = "original";
				char const *value = buffer, *got = nullptr;
				[invocation setArgument:&value atIndex:2];
				[invocation retainArguments];
				buffer[0] = 'X';
				[invocation getArgument:&got atIndex:2];
				TEST(got != value);
				TEST_STR_EQ(got, "original");
			} else {
				__attribute__((objc_precise_lifetime)) OwnershipObject *object = [OwnershipObject new];
				id __unsafe_unretained value = object;
				size_t before = object_getRetainCount_np(object);
				[invocation setArgument:&value atIndex:2];
				[invocation retainArguments];
				TEST_EQ_UNSIGNED(object_getRetainCount_np(object), before + 1);
			}
		}
	TEST_EQ(LiveObjects, 0);
}

static void
TestObjects(char const *qualifiers, bool returnSlot, bool retainFirst)
{
	@autoreleasepool {
		NSInvocation *invocation = NewInvocation(qualifiers, "@", returnSlot);
		__attribute__((objc_precise_lifetime)) OwnershipObject *object = [OwnershipObject new];
		id __unsafe_unretained value = object;
		id __unsafe_unretained got = nil;
		size_t before = object_getRetainCount_np(object);
		if (retainFirst) [invocation retainArguments];
		Put(invocation, returnSlot, &value);
		TEST_EQ_UNSIGNED(object_getRetainCount_np(object), before + (retainFirst ? 1U : 0U));
		[invocation retainArguments];
		[invocation retainArguments];
		TEST_EQ_UNSIGNED(object_getRetainCount_np(object), before + 1);
		/* Do not dereference a dangling pointer if a regression already failed to retain this value. */
		if (object_getRetainCount_np(object) != before + 1) return;
		object = nil;
		TEST_EQ(LiveObjects, 1);
		for (unsigned i = 0; i < 8; ++i) {
			Get(invocation, returnSlot, &got);
			Put(invocation, returnSlot, &got); /* Invocation is the sole owner. */
			TEST_EQ(LiveObjects, 1);
			TEST_EQ_UNSIGNED(object_getRetainCount_np(got), 1);
		}
		__attribute__((objc_precise_lifetime)) OwnershipObject *replacement = [OwnershipObject new];
		value = replacement;
		Put(invocation, returnSlot, &value);
		TEST_EQ(LiveObjects, 1);
		replacement = nil;
		Get(invocation, returnSlot, &got);
		TEST_EQ_UNSIGNED(object_getRetainCount_np(got), 1);
		value = nil;
		Put(invocation, returnSlot, &value);
		Put(invocation, returnSlot, &value);
		Get(invocation, returnSlot, &got);
		TEST(got == nil);
		TEST_EQ(LiveObjects, 0);
	}
	TEST_EQ(LiveObjects, 0);
}

static void
TestStrings(char const *qualifiers, bool returnSlot, bool retainFirst)
{
	@autoreleasepool {
		NSInvocation *invocation = NewInvocation(qualifiers, "*", returnSlot);
		char buffer[] = "original";
		char *value = buffer, *got = nullptr;
		if (retainFirst) [invocation retainArguments];
		Put(invocation, returnSlot, &value);
		[invocation retainArguments];
		[invocation retainArguments];
		buffer[0] = 'X';
		Get(invocation, returnSlot, &got);
		TEST(got != value);
		TEST_STR_EQ(got, "original");
		if (got == value) return;
		for (unsigned i = 0; i < 8; ++i) {
			Put(invocation, returnSlot, &got);
			Get(invocation, returnSlot, &got);
			TEST_STR_EQ(got, "original");
		}
		/* Pointer-equality shortcuts alone cannot fix an incoming substring of the old allocation. */
		value = got + 2;
		Put(invocation, returnSlot, &value);
		Get(invocation, returnSlot, &got);
		TEST_STR_EQ(got, "iginal");
		char replacement[] = "replacement";
		value = replacement;
		Put(invocation, returnSlot, &value);
		replacement[0] = 'X';
		Get(invocation, returnSlot, &got);
		TEST_STR_EQ(got, "replacement");
		value = "";
		Put(invocation, returnSlot, &value);
		Get(invocation, returnSlot, &got);
		TEST_STR_EQ(got, "");
		value = nullptr;
		Put(invocation, returnSlot, &value);
		Put(invocation, returnSlot, &value);
		Get(invocation, returnSlot, &got);
		TEST(got == nullptr);
	}
}

/* The unsafe local deliberately avoids ARC copying the Block on assignment: the invocation must make it escape. */
[[gnu::noinline]]
static void
InstallCapturingBlock(NSInvocation *invocation, bool returnSlot, bool retainFirst)
{
	OwnershipObject *object = [OwnershipObject new];
	object.value = 731;
	int (^__unsafe_unretained block)(void) = ^{ return object.value; };
	if (retainFirst) [invocation retainArguments];
	Put(invocation, returnSlot, &block);
	if (!retainFirst) [invocation retainArguments];
}

static void
TestBlocks(char const *qualifiers, bool returnSlot, bool retainFirst)
{
	@autoreleasepool {
		NSInvocation *invocation = NewInvocation(qualifiers, "@?", returnSlot);
		InstallCapturingBlock(invocation, returnSlot, retainFirst);
		TEST_EQ(LiveObjects, 1);
		if (LiveObjects != 1) return;
		int (^__unsafe_unretained block)(void) = nil;
		Get(invocation, returnSlot, &block);
		TEST_EQ(block(), 731);
		[invocation retainArguments];
		Put(invocation, returnSlot, &block);
		Get(invocation, returnSlot, &block);
		TEST_EQ(block(), 731);
		int (^__unsafe_unretained global)(void) = ^{ return 197; };
		Put(invocation, returnSlot, &global);
		TEST_EQ(LiveObjects, 0);
		Get(invocation, returnSlot, &block);
		TEST_EQ(block(), 197);
		block = nil;
		Put(invocation, returnSlot, &block);
		Get(invocation, returnSlot, &block);
		TEST(block == nil);
	}
	TEST_EQ(LiveObjects, 0);
}

static void
TestTargetAndPointerBoundaries(void)
{
	@autoreleasepool {
		NSInvocation *invocation = NewInvocation("", "@", false);
		OwnershipObject *object = [OwnershipObject new];
		id __unsafe_unretained value = object;
		[invocation setArgument:&value atIndex:0];
		[invocation retainArguments];
		object = nil;
		[invocation getArgument:&value atIndex:0];
		[invocation setArgument:&value atIndex:0];
		TEST_EQ(LiveObjects, 1);
		TEST_EQ_UNSIGNED(object_getRetainCount_np(value), 1);
		invocation.target = value;
		TEST_EQ_UNSIGNED(object_getRetainCount_np(value), 1);
		value = nil;
		[invocation setArgument:&value atIndex:0];
		TEST_EQ(LiveObjects, 0);
	}
	char const *const types[] = {"^@", "^*", "r^@", "r^*", "[4C]", "rn[4C]"};
	for (NSUInteger i = 0; i < sizeof(types) / sizeof(types[0]); ++i)
		@autoreleasepool {
			NSInvocation *invocation = NewInvocation("", types[i], false);
			unsigned char bytes[4] = {0xff, 0xfe, 0xfd, 0xfc};
			void *value = bytes, *got = nullptr;
			[invocation setArgument:&value atIndex:2];
			[invocation retainArguments];
			[invocation getArgument:&got atIndex:2];
			TEST(got == value);
			[invocation setArgument:&got atIndex:2];
		}
}

typedef int (^ReadBlock)(void);

@interface OwnershipReceiver : NSObject
- (bycopy id)objectResult;
- (const char *)textResult;
- (void)run:(in ReadBlock)block;
@end
@implementation OwnershipReceiver {
@public
	OwnershipObject *held;
	char const *text;
	int observed;
}
- (bycopy id)objectResult { return held; }
- (const char *)textResult { return text; }
- (void)run:(in ReadBlock)block { observed = block(); }
@end

@interface DeferredOwnershipProxy : NSObject
+ (instancetype)proxyWithReceiver:(OwnershipReceiver *)receiver;
- (void)fire;
- (void)clear;
@end
@implementation DeferredOwnershipProxy {
	OwnershipReceiver *_receiver;
	NSInvocation *_pending;
}
+ (instancetype)proxyWithReceiver:(OwnershipReceiver *)receiver
{
	DeferredOwnershipProxy *proxy = [self new];
	proxy->_receiver = receiver;
	return proxy;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	return [_receiver methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
	/* Retarget before retaining so the queued invocation does not retain the proxy that owns it. */
	invocation.target = _receiver;
	[invocation retainArguments];
	_pending = invocation;
}
- (void)fire { [_pending invoke]; }
- (void)clear { _pending = nil; }
@end

static void
TestInvokedReturnsAndDeferredForwarding(void)
{
	@autoreleasepool {
		OwnershipReceiver *receiver = [OwnershipReceiver new];
		receiver->held = [OwnershipObject new];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
			[receiver methodSignatureForSelector:@selector(objectResult)]];
		TEST_STR_EQ(invocation.methodSignature.methodReturnType, "O@");
		invocation.target = receiver;
		invocation.selector = @selector(objectResult);
		[invocation retainArguments];
		size_t before = object_getRetainCount_np(receiver->held);
		for (unsigned i = 0; i < 8; ++i) {
			@autoreleasepool {
				[invocation invoke];
				id __unsafe_unretained got = nil;
				[invocation getReturnValue:&got];
				TEST(got == receiver->held);
			}
			TEST_EQ_UNSIGNED(object_getRetainCount_np(receiver->held), before + 1);
		}
		invocation.target = nil;
		[invocation invoke];
		TEST_EQ_UNSIGNED(object_getRetainCount_np(receiver->held), before);
		receiver->held = nil;
		TEST_EQ(LiveObjects, 0);

		char buffer[] = "original";
		receiver->text = buffer;
		invocation = [NSInvocation invocationWithMethodSignature:
			[receiver methodSignatureForSelector:@selector(textResult)]];
		TEST_STR_EQ(invocation.methodSignature.methodReturnType, "r*");
		invocation.target = receiver;
		invocation.selector = @selector(textResult);
		[invocation retainArguments];
		[invocation invoke];
		buffer[0] = 'X';
		char const *got = nullptr;
		[invocation getReturnValue:&got];
		TEST(got != buffer);
		TEST_STR_EQ(got, "original");
		for (unsigned i = 0; i < 8; ++i) {
			[invocation invoke];
			[invocation getReturnValue:&got];
			TEST_STR_EQ(got, "Xriginal");
		}
		receiver->text = nullptr;
		[invocation invoke];
		[invocation getReturnValue:&got];
		TEST(got == nullptr);
		invocation.target = nil;
		[invocation invoke];
		[invocation getReturnValue:&got];
		TEST(got == nullptr);

		DeferredOwnershipProxy *proxy = [DeferredOwnershipProxy proxyWithReceiver:receiver];
		@autoreleasepool {
			OwnershipObject *captured = [OwnershipObject new];
			captured.value = 811;
			ReadBlock __unsafe_unretained block = ^{ return captured.value; };
			[(OwnershipReceiver *)proxy run:block];
		}
		TEST_EQ(LiveObjects, 1);
		if (LiveObjects == 1) {
			[proxy fire];
			TEST_EQ(receiver->observed, 811);
		}
		[proxy clear];
		TEST_EQ(LiveObjects, 0);
	}
	TEST_EQ(LiveObjects, 0);
}

int
main(int argc, char **argv)
{
	/* Include every qualifier understood by the parser, plus a run that defeats a single-character skip. */
	char const *const qualifiers[] = {"", "r", "n", "N", "o", "O", "R", "V", "A", "rnNoORVA"};
	char const *group = argc > 1 ? argv[1] : "all";
	bool all = strcmp(group, "all") == 0;
	if (all || strcmp(group, "metadata") == 0) TestCompilerQualifiers();
	for (NSUInteger q = 0; q < sizeof(qualifiers) / sizeof(qualifiers[0]); ++q)
		for (unsigned slot = 0; slot < 2; ++slot)
			for (unsigned first = 0; first < 2; ++first) {
				if (all || strcmp(group, "objects") == 0) TestObjects(qualifiers[q], slot != 0, first != 0);
				if (all || strcmp(group, "strings") == 0) TestStrings(qualifiers[q], slot != 0, first != 0);
				if (all || strcmp(group, "blocks") == 0) TestBlocks(qualifiers[q], slot != 0, first != 0);
			}
	if (all || strcmp(group, "boundaries") == 0) TestTargetAndPointerBoundaries();
	if (all || strcmp(group, "boundaries") == 0) TestNilTargetReleasesStoredObjects();
	if (all || strcmp(group, "invocation") == 0) TestInvokedReturnsAndDeferredForwarding();
	return TestFinish();
}

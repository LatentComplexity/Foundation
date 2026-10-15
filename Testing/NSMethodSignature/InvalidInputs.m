#import <Foundation/NSException.h>
#import <Foundation/NSMethodSignature.h>
#import "Test.h"

static void
TestNullEmptyAndUnavailableInitialization(void)
{
	@autoreleasepool {
		char const *nullTypes = nullptr;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[NSMethodSignature signatureWithObjCTypes:nullTypes]);
#pragma clang diagnostic pop
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[NSMethodSignature signatureWithObjCTypes:""]);

		/* Send -init through id to deliberately evade its compile-time unavailability. */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-messaging-id"
		TEST_THROWS_NAME(NSUnavailableMethodUsageException,
			(void)[(id)[NSMethodSignature alloc] init]);

		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
		TEST_THROWS_NAME(NSUnavailableMethodUsageException, (void)[(id)signature init]);
#pragma clang diagnostic pop
	}
}

static void
TestMalformedEncodings(void)
{
	@autoreleasepool {
		char const *const malformed[] = {
			"r",
			"^",
			"v@:r",
			"v@:^",
			"v@:!",
			"v@:]",
			"v@:}",
			"v@:)",
			"v@:[",
			"v@:[3i",
			"v@:{Pair=ii",
			"v@:{Pair=i]}",
			"v@:@\"NSObject\"",
			"v@:@?<Protocol>",
			"v@:{Pair=\"x\"i\"y\"i}",
			"v@:{Outer=[2!]}",
			"v@:j!",
			"v@:b",
			"v@:[184467440737095516160i]",
			"v184467440737095516160@:"
		};

		for (NSUInteger i = 0; i < sizeof(malformed) / sizeof(malformed[0]); ++i)
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[NSMethodSignature signatureWithObjCTypes:malformed[i]]);

		char deeplyNested[512];
		char *p = deeplyNested;
		*p++ = 'v';
		*p++ = '@';
		*p++ = ':';
		for (NSUInteger i = 0; i < 130; ++i) {
			*p++ = '[';
			*p++ = '1';
		}
		*p++ = 'i';
		for (NSUInteger i = 0; i < 130; ++i)
			*p++ = ']';
		*p = '\0';

		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[NSMethodSignature signatureWithObjCTypes:deeplyNested]);
	}
}

static void
TestMethodShapeRestrictions(void)
{
	@autoreleasepool {
		char const *const badShapes[] = {
			"v",
			"v@",
			"v:",
			"vi:",
			"v@i",
			"v@@",
			"v@?i:",
			"vV@:",
			"v@r:",
			"v:i@",
			"[3i]@:",
			"r[3i]@:"
		};

		for (NSUInteger i = 0; i < sizeof(badShapes) / sizeof(badShapes[0]); ++i)
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[NSMethodSignature signatureWithObjCTypes:badShapes[i]]);
	}
}

static void
TestNonInvocableTypes(void)
{
	@autoreleasepool {
		char const *const nonInvocable[] = {
			"D@:",
			"t@:",
			"T@:",
			"jc@:",
			"jC@:",
			"js@:",
			"jS@:",
			"ji@:",
			"jI@:",
			"jl@:",
			"jL@:",
			"jq@:",
			"jQ@:",
			"jf@:",
			"jd@:",
			"jD@:",
			"(Either=iq)@:",
			"b7@:",
			"v@:D",
			"v@:^t",
			"v@:[2T]",
			"v@:{Outer=(Either=ii)}",
			"v@:b7"
		};

		for (NSUInteger i = 0; i < sizeof(nonInvocable) / sizeof(nonInvocable[0]); ++i)
			TEST_THROWS_NAME(NSInvalidArgumentException,
				(void)[NSMethodSignature signatureWithObjCTypes:nonInvocable[i]]);
	}
}

static void
TestInvalidMethodQueries(void)
{
	@autoreleasepool {
		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:i"];
		NSMethodSignature *nilSignature = nil;

		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[signature getArgumentTypeAtIndex:signature.numberOfArguments]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[signature getArgumentTypeAtIndex:NSUIntegerMax]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[signature isEqualToMethodSignature:nilSignature]);
	}
}

int
main(void)
{
	TestNullEmptyAndUnavailableInitialization();
	TestMalformedEncodings();
	TestMethodShapeRestrictions();
	TestNonInvocableTypes();
	TestInvalidMethodQueries();

	return TestFinish();
}

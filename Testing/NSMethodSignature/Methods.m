#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSString.h>
#import "Test.h"

#import <objc/runtime.h>

static void
TestPropertiesAndArgumentQueries(void)
{
	@autoreleasepool {
		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:
			"V{Result=ci}32@0:8rC16[3s]24"];

		TEST_STR_EQ(object_getClassName(signature), "NSMethodSignature");
		TEST_STR_EQ(signature.methodReturnType, "V{Result=ci}");
		TEST_EQ_UNSIGNED(signature.methodReturnLength, 8);
		TEST_EQ_UNSIGNED(signature.numberOfArguments, 4);
		TEST_EQ_UNSIGNED(signature.frameLength, 32);
		TEST_STR_EQ([signature getArgumentTypeAtIndex:0], "@");
		TEST_STR_EQ([signature getArgumentTypeAtIndex:1], ":");
		TEST_STR_EQ([signature getArgumentTypeAtIndex:2], "rC");
		TEST_STR_EQ([signature getArgumentTypeAtIndex:3], "[3s]");
	}
}

static void
TestOnewayQualifier(void)
{
	@autoreleasepool {
		TEST(![[NSMethodSignature signatureWithObjCTypes:"v@:"] isOneway]);
		TEST([[NSMethodSignature signatureWithObjCTypes:"Vv@:"] isOneway]);
		TEST([[NSMethodSignature signatureWithObjCTypes:"rNAVv@:"] isOneway]);
		TEST([[NSMethodSignature signatureWithObjCTypes:"V^i@:"] isOneway]);
		TEST(![[NSMethodSignature signatureWithObjCTypes:"^Vi@:"] isOneway]);
		TEST(![[NSMethodSignature signatureWithObjCTypes:"v@:Vi"] isOneway]);
	}
}

static void
TestEqualityAndHashing(void)
{
	@autoreleasepool {
		NSMethodSignature *plain = [NSMethodSignature signatureWithObjCTypes:"v@:i"];
		NSMethodSignature *withOffsets = [NSMethodSignature signatureWithObjCTypes:"v24@0:8i16"];
		NSMethodSignature *differentReturn = [NSMethodSignature signatureWithObjCTypes:"i@:i"];
		NSMethodSignature *differentCount = [NSMethodSignature signatureWithObjCTypes:"v@:ii"];
		NSMethodSignature *differentArgument = [NSMethodSignature signatureWithObjCTypes:"v@:q"];
		NSMethodSignature *qualifiedArgument = [NSMethodSignature signatureWithObjCTypes:"v@:ri"];
		NSMethodSignature *firstTag = [NSMethodSignature signatureWithObjCTypes:"v@:{First=i}"];
		NSMethodSignature *secondTag = [NSMethodSignature signatureWithObjCTypes:"v@:{Second=i}"];
		NSUInteger const hash = plain.hash;

		TEST([plain isEqualToMethodSignature:plain]);
		TEST([plain isEqual:plain]);
		TEST([plain isEqualToMethodSignature:withOffsets]);
		TEST([withOffsets isEqualToMethodSignature:plain]);
		TEST([plain isEqual:withOffsets]);
		TEST([withOffsets isEqual:plain]);
		TEST_EQ_UNSIGNED(hash, plain.hash);
		TEST_EQ_UNSIGNED(hash, plain.hash);
		TEST_EQ_UNSIGNED(hash, withOffsets.hash);

		TEST(![plain isEqualToMethodSignature:differentReturn]);
		TEST(![plain isEqualToMethodSignature:differentCount]);
		TEST(![plain isEqualToMethodSignature:differentArgument]);
		TEST(![plain isEqualToMethodSignature:qualifiedArgument]);
		TEST(![firstTag isEqualToMethodSignature:secondTag]);
		TEST(![plain isEqual:differentReturn]);
		TEST(![plain isEqual:@"v@:i"]);
		TEST(![plain isEqual:nil]);
	}
}

int
main(void)
{
	TestPropertiesAndArgumentQueries();
	TestOnewayQualifier();
	TestEqualityAndHashing();

	return TestFinish();
}

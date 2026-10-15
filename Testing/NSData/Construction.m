#import <Foundation/NSData.h>
#import "Test.h"

#import <objc/runtime.h>

#include <stdlib.h>
#include <string.h>

static void
TestObject(NSData *data, char const *className, void const *bytes, NSUInteger count)
{
	TEST(data != nil);
	TEST_STR_EQ(object_getClassName(data), className);
	TEST_EQ_UNSIGNED(data.count, count);
	if (count > 0)
		TEST_BYTES_EQ(data.bytes, bytes, count);
}

static void
TestImmutableConstruction(void)
{
	@autoreleasepool {
		NSData *data = [NSData data];

		TestObject(data, "NSZeroData", nullptr, 0);
		TEST(data == [NSData data]);
	}

	@autoreleasepool {
		NSData *data = [[NSData alloc] init];

		TestObject(data, "NSZeroData", nullptr, 0);
	}

	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:"bytes" count:5];

		TestObject(data, "NSInlineData", "bytes", 5);
	}

	@autoreleasepool {
		NSData *data = [[NSData alloc] initWithBytes:"contents" count:8];

		TestObject(data, "NSInlineData", "contents", 8);
	}

	@autoreleasepool {
		NSData *source = [NSData dataWithBytes:"copy" count:4];
		NSData *data = [NSData dataWithData:source];

		TestObject(data, "NSInlineData", "copy", 4);
		TEST(data == source);
	}

	@autoreleasepool {
		NSMutableData *source = [[NSMutableData alloc] initWithBytes:"snapshot" count:8];
		NSData *data = [[NSData alloc] initWithData:source];

		TestObject(data, "NSInlineData", "snapshot", 8);
		TEST((id)data != (id)source);
		[source appendBytes:"!" count:1];
		TEST_EQ_UNSIGNED(data.count, 8);
		TEST_BYTES_EQ(data.bytes, "snapshot", 8);
	}
}

static void
TestImmutableNoCopyConstruction(void)
{
	@autoreleasepool {
		void *bytes = malloc(6);
		memcpy(bytes, "malloc", 6);
		NSData *data = [NSData dataWithBytesNoCopy:bytes count:6];

		TestObject(data, "NSInlineData", "malloc", 6);
		TEST(data.bytes == bytes);
	}

	@autoreleasepool {
		char bytes[] = "borrowed";
		NSData *data = [NSData dataWithBytesNoCopy:bytes count:8 freeWhenDone:false];

		TestObject(data, "NSInlineData", "borrowed", 8);
		TEST(data.bytes == bytes);
	}

	@autoreleasepool {
		void *bytes = malloc(1);
		NSData *data = [NSData dataWithBytesNoCopy:bytes count:0 freeWhenDone:true];

		TestObject(data, "NSZeroData", nullptr, 0);
	}

	@autoreleasepool {
		__block unsigned deallocations = 0;
		void *bytes = malloc(5);
		memcpy(bytes, "block", 5);

		@autoreleasepool {
			NSData *data = [[NSData alloc] initWithBytesNoCopy:bytes count:5
				deallocator:^(void *ownedBytes, NSUInteger count) {
					TEST_EQ_UNSIGNED(count, 5);
					++deallocations;
					free(ownedBytes);
				}];

			TestObject(data, "NSInlineData", "block", 5);
			TEST_EQ_UNSIGNED(deallocations, 0);
		}

		TEST_EQ_UNSIGNED(deallocations, 1);
	}

	@autoreleasepool {
		__block unsigned deallocations = 0;
		void *bytes = malloc(1);
		NSData *data = [[NSData alloc] initWithBytesNoCopy:bytes count:0
			deallocator:^(void *ownedBytes, NSUInteger count) {
				TEST_EQ_UNSIGNED(count, 0);
				++deallocations;
				free(ownedBytes);
			}];

		TestObject(data, "NSZeroData", nullptr, 0);
		TEST_EQ_UNSIGNED(deallocations, 1);
	}
}

static void
TestMutableConstruction(void)
{
	@autoreleasepool {
		NSMutableData *data = [NSMutableData data];

		TestObject(data, "NSMutableInlineData", nullptr, 0);
		TEST(data.mutableBytes != nullptr);
		TEST(data != [NSMutableData data]);
	}

	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] init];

		TestObject(data, "NSMutableInlineData", nullptr, 0);
		TEST(data.mutableBytes != nullptr);
	}

	@autoreleasepool {
		NSMutableData *data = [NSMutableData dataWithCapacity:32];

		TestObject(data, "NSMutableInlineData", nullptr, 0);
		TEST(data.mutableBytes != nullptr);
	}

	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithCapacity:32];

		TestObject(data, "NSMutableInlineData", nullptr, 0);
	}

	@autoreleasepool {
		unsigned char const zeroes[7] = { 0 };
		NSMutableData *data = [NSMutableData dataWithCount:7];

		TestObject(data, "NSMutableInlineData", zeroes, sizeof(zeroes));
	}

	@autoreleasepool {
		unsigned char const zeroes[7] = { 0 };
		NSMutableData *data = [[NSMutableData alloc] initWithCount:7];

		TestObject(data, "NSMutableInlineData", zeroes, sizeof(zeroes));
	}

	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"mutable" count:7];

		TestObject(data, "NSMutableInlineData", "mutable", 7);
	}

	@autoreleasepool {
		NSData *source = [NSData dataWithBytes:"source" count:6];
		NSMutableData *data = [[NSMutableData alloc] initWithData:source];

		TestObject(data, "NSMutableInlineData", "source", 6);
		TEST((id)data != (id)source);
		TEST(data.bytes == source.bytes);
	}
}

static void
TestMutableNoCopyConstruction(void)
{
	@autoreleasepool {
		void *bytes = malloc(5);
		memcpy(bytes, "owned", 5);
		NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:bytes count:5];

		TestObject(data, "NSMutableInlineData", "owned", 5);
		TEST(data.bytes == bytes);
	}

	@autoreleasepool {
		char bytes[] = "borrowed";
		NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:bytes count:8 freeWhenDone:false];

		TestObject(data, "NSMutableInlineData", "borrowed", 8);
		TEST(data.bytes == bytes);
	}

	@autoreleasepool {
		void *bytes = malloc(1);
		NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:bytes count:0 freeWhenDone:true];

		TestObject(data, "NSMutableInlineData", nullptr, 0);
		TEST(data.mutableBytes != nullptr);
	}

	@autoreleasepool {
		__block unsigned deallocations = 0;
		void *bytes = malloc(4);
		memcpy(bytes, "done", 4);

		@autoreleasepool {
			NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:bytes count:4
				deallocator:^(void *ownedBytes, NSUInteger count) {
					TEST_EQ_UNSIGNED(count, 4);
					++deallocations;
					free(ownedBytes);
				}];

			TestObject(data, "NSMutableInlineData", "done", 4);
			TEST_EQ_UNSIGNED(deallocations, 0);
		}

		TEST_EQ_UNSIGNED(deallocations, 1);
	}
}

int
main(void)
{
	TestImmutableConstruction();
	TestImmutableNoCopyConstruction();
	TestMutableConstruction();
	TestMutableNoCopyConstruction();

	return TestFinish();
}

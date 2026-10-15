#import <Foundation/NSData.h>
#import "Test.h"

#include <stdint.h>

@interface HugeData : NSData
@end

@implementation HugeData

- (void const *)bytes
{
	static unsigned char byte;

	return &byte;
}

- (NSUInteger)count
{
	return NSUIntegerMax;
}

@end

static void
TestInvalidInitializers(void)
{
	@autoreleasepool {
		NSData *nilData = nil;

		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[NSData dataWithData:nilData]);
	}

	@autoreleasepool {
		NSData *nilData = nil;

		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[[NSData alloc] initWithData:nilData]);
	}

	@autoreleasepool {
		NSData *nilData = nil;

		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[[NSMutableData alloc] initWithData:nilData]);
	}

	@autoreleasepool {
		void *nullBytes = nullptr;

		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[NSData dataWithBytes:nullBytes count:0]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSData alloc] initWithBytes:nullBytes count:1]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSMutableData alloc] initWithBytes:nullBytes count:0]);
	}

	@autoreleasepool {
		void *nullBytes = nullptr;

		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[NSData dataWithBytesNoCopy:nullBytes count:0]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[NSData dataWithBytesNoCopy:nullBytes count:0 freeWhenDone:false]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSData alloc] initWithBytesNoCopy:nullBytes count:0 deallocator:nil]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			(void)[[NSMutableData alloc] initWithBytesNoCopy:nullBytes count:0]);
	}
}

static void
TestReinitialization(void)
{
	@autoreleasepool {
		NSData *data = [NSData data];

		TEST_THROWS_NAME(NSUnavailableMethodUsageException, (void)[data initWithBytes:"x" count:1]);
	}

	@autoreleasepool {
		char bytes[] = "data";
		NSData *data = [NSData dataWithBytesNoCopy:bytes count:4 freeWhenDone:false];

		TEST_THROWS_NAME(NSUnavailableMethodUsageException, (void)[data initWithData:data]);
		TEST_THROWS_NAME(NSUnavailableMethodUsageException,
			(void)[data initWithBytesNoCopy:bytes count:data.count freeWhenDone:false]);
	}

	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"data" count:4];

		TEST_THROWS_NAME(NSUnavailableMethodUsageException, (void)[data initWithCapacity:8]);
		TEST_THROWS_NAME(NSUnavailableMethodUsageException, (void)[data initWithCount:8]);
		TEST_THROWS_NAME(NSUnavailableMethodUsageException, (void)[data initWithBytes:"x" count:1]);
	}
}

static void
TestInvalidImmutableMethods(void)
{
	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:"01234567" count:8];
		void *nullBytes = nullptr;

		TEST_THROWS_NAME(NSInvalidArgumentException, [data getBytes:nullBytes count:0]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[data getBytes:nullBytes range:NSRangeMake(0, 0)]);
	}

	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:"01234567" count:8];

		TEST_THROWS_NAME(NSRangeException, (void)[data subdataWithRange:NSRangeMake(9, 0)]);
		TEST_THROWS_NAME(NSRangeException, (void)[data subdataWithRange:NSRangeMake(7, 2)]);
		TEST_THROWS_NAME(NSRangeException,
			(void)[data subdataWithRange:NSRangeMake(NSUIntegerMax, 1)]);
		TEST_THROWS_NAME(NSRangeException,
			[data getBytes:(unsigned char[1]){ 0 } range:NSRangeMake(8, 1)]);
	}

	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:"01234567" count:8];
		NSData *nilData = nil;
		void (^nilBlock)(void const *, NSRange, bool *) = nil;

		TEST_THROWS_NAME(NSInvalidArgumentException, [data enumerateByteRangesUsingBlock:nilBlock]);
		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[data rangeOfData:nilData
			options:NSDataSearchDefault range:NSRangeMake(0, data.count)]);
		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[data isEqualToData:nilData]);
	}

	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:"01234567" count:8];
		NSData *needle = [NSData dataWithBytes:"0" count:1];

		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[data rangeOfData:needle
			options:(NSDataSearchOptions)(1UL << 2) range:NSRangeMake(0, data.count)]);
		TEST_THROWS_NAME(NSRangeException, (void)[data rangeOfData:needle
			options:NSDataSearchDefault range:NSRangeMake(7, 2)]);
		TEST_THROWS_NAME(NSRangeException, (void)[data rangeOfData:needle
			options:NSDataSearchDefault range:NSRangeMake(NSUIntegerMax, 1)]);
	}

	@autoreleasepool {
		NSData *data = [NSData data];
		NSData *nilData = nil;
		void (^nilBlock)(void const *, NSRange, bool *) = nil;

		TEST_THROWS_NAME(NSInvalidArgumentException, [data enumerateByteRangesUsingBlock:nilBlock]);
		TEST_THROWS_NAME(NSInvalidArgumentException, (void)[data isEqualToData:nilData]);
	}
}

static void
TestInvalidMutableMethods(void)
{
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"01234567" count:8];
		void *nullBytes = nullptr;
		NSData *nilData = nil;

		TEST_THROWS_NAME(NSInvalidArgumentException, [data appendBytes:nullBytes count:0]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [data appendData:nilData]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[data replaceBytesInRange:NSRangeMake(0, 0) withBytes:nullBytes]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[data replaceBytesInRange:NSRangeMake(0, 0) withBytes:nullBytes count:0]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [data setData:nilData]);
	}

	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"01234567" count:8];

		TEST_THROWS_NAME(NSRangeException,
			[data replaceBytesInRange:NSRangeMake(9, 0) withBytes:"x" count:1]);
		TEST_THROWS_NAME(NSRangeException,
			[data replaceBytesInRange:NSRangeMake(NSUIntegerMax, 1) withBytes:"x" count:1]);
		TEST_THROWS_NAME(NSRangeException, [data resetBytesInRange:NSRangeMake(7, 2)]);
	}

	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"x" count:1];
		HugeData *huge = [HugeData new];

		TEST_THROWS_NAME(NSInvalidArgumentException, [data increaseCountBy:NSUIntegerMax]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [data appendBytes:"x" count:NSUIntegerMax]);
		TEST_THROWS_NAME(NSInvalidArgumentException, [data appendData:huge]);
		TEST_THROWS_NAME(NSInvalidArgumentException,
			[data replaceBytesInRange:NSRangeMake(0, 0) withBytes:"x" count:NSUIntegerMax]);
	}
}

int
main(void)
{
	TestInvalidInitializers();
	TestReinitialization();
	TestInvalidImmutableMethods();
	TestInvalidMutableMethods();

	return TestFinish();
}

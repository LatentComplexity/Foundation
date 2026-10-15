#import <Foundation/NSData.h>
#import "Test.h"

#import <objc/runtime.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

@interface TestData : NSData

- (instancetype)initWithTestBytes:(void const *)bytes count:(NSUInteger)count;

@end


@implementation TestData {
	unsigned char _storage[520];
	NSUInteger _length;
}

- (instancetype)initWithTestBytes:(void const *)bytes count:(NSUInteger)count
{
	self = [super init];
	if (self != nil) {
		_length = count;
		if (count > 0)
			memcpy(_storage, bytes, count);
	}

	return self;
}

- (void const *)bytes
{
	return _storage;
}

- (NSUInteger)count
{
	return _length;
}

@end


@interface TestMutableData : NSMutableData

- (instancetype)initWithTestBytes:(void const *)bytes count:(NSUInteger)count;

@end


@implementation TestMutableData {
	unsigned char _storage[520];
	NSUInteger _length;
}

- (instancetype)initWithTestBytes:(void const *)bytes count:(NSUInteger)count
{
	self = [super init];
	if (self != nil) {
		_length = count;
		if (count > 0)
			memcpy(_storage, bytes, count);
	}

	return self;
}

- (void const *)bytes
{
	return _storage;
}

- (void *)mutableBytes
{
	return _storage;
}

- (NSUInteger)count
{
	return _length;
}

- (void)setCount:(NSUInteger)count
{
	if (count > _length)
		memset(_storage + _length, 0, count - _length);

	_length = count;
}

@end


static void
TestRange(NSRange actual, NSUInteger location, NSUInteger length)
{
	TEST_EQ_UNSIGNED(actual.location, location);
	TEST_EQ_UNSIGNED(actual.length, length);
}

static void
TestCommonMethods(NSData *data, char const *className, void const *expectedBytes, NSUInteger count)
{
	unsigned char copied[32];
	__block unsigned enumerations = 0;
	__block bool initialStop = true;
	NSData *equal;
	NSData *copy;
	NSMutableData *mutableCopy;
	NSData *full;
	NSData *empty;

	memset(copied, 0xa5, sizeof(copied));
	equal = [NSData dataWithBytes:expectedBytes count:count];

	TEST_STR_EQ(object_getClassName(data), className);
	TEST_EQ_UNSIGNED(data.count, count);
	TEST_BYTES_EQ(data.bytes, expectedBytes, count);
	TEST([data isEqualToData:equal]);
	TEST([data isEqual:equal]);
	TEST_EQ_UNSIGNED(data.hash, equal.hash);
	TEST(![data isEqual:@"not data"]);

	[data getBytes:copied count:count + 2];
	TEST_BYTES_EQ(copied, expectedBytes, count);
	TEST_EQ_UNSIGNED(copied[count], 0xa5);

	if (count > 1) {
		memset(copied, 0xa5, sizeof(copied));
		[data getBytes:copied range:NSRangeMake(1, count - 1)];
		TEST_BYTES_EQ(copied, (unsigned char const *)expectedBytes + 1, count - 1);
		TEST_EQ_UNSIGNED(copied[count - 1], 0xa5);
	}

	[data enumerateByteRangesUsingBlock:^(void const *bytes, NSRange range, bool *stop) {
		++enumerations;
		initialStop = *stop;
		TEST(bytes == data.bytes);
		TestRange(range, 0, count);
		*stop = true;
	}];
	TEST_EQ_UNSIGNED(enumerations, 1);
	TEST(initialStop == false);

	copy = [data copy];
	if ([data isKindOfClass:[NSMutableData class]]) {
		TEST((id)copy != (id)data);
		TEST_STR_EQ(object_getClassName(copy), count == 0 ? "NSZeroData" : "NSInlineData");
	} else
		TEST(copy == data);
	TEST([copy isEqualToData:data]);

	mutableCopy = [data mutableCopy];
	TEST((id)mutableCopy != (id)data);
	TEST_STR_EQ(object_getClassName(mutableCopy), "NSMutableInlineData");
	TEST([mutableCopy isEqualToData:data]);
	TEST(mutableCopy.mutableBytes != nullptr);

	full = [data subdataWithRange:NSRangeMake(0, count)];
	if ([data isKindOfClass:[NSMutableData class]])
		TEST((id)full != (id)data);
	else
		TEST(full == data);
	TEST([full isEqualToData:data]);

	empty = [data subdataWithRange:NSRangeMake(count, 0)];
	TEST_STR_EQ(object_getClassName(empty), "NSZeroData");
	TEST_EQ_UNSIGNED(empty.count, 0);

	if (count > 2) {
		NSData *middle = [data subdataWithRange:NSRangeMake(1, count - 2)];

		TEST_STR_EQ(object_getClassName(middle),
			[data isKindOfClass:[TestData class]] || [data isKindOfClass:[TestMutableData class]] ?
			"NSInlineData" : "NSSubrangeData");
		TEST_BYTES_EQ(middle.bytes, (unsigned char const *)expectedBytes + 1, count - 2);
	}
}

static void
TestEveryRepresentation(void)
{
	@autoreleasepool {
		NSData *data = [NSData data];
		unsigned char byte = 0;

		TestCommonMethods(data, "NSZeroData", &byte, 0);
		TEST(data.bytes == nullptr);
		TestRange([data rangeOfData:[NSData data] options:NSDataSearchDefault range:NSRangeMake(0, 0)], 0, 0);
	}

	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:"0123456789" count:10];

		TestCommonMethods(data, "NSInlineData", "0123456789", 10);
	}

	@autoreleasepool {
		NSData *parent = [NSData dataWithBytes:"--subrange--" count:12];
		NSData *data = [parent subdataWithRange:NSRangeMake(2, 8)];

		TestCommonMethods(data, "NSSubrangeData", "subrange", 8);
		TEST((char const *)data.bytes == (char const *)parent.bytes + 2);
	}

	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"mutable" count:7];

		TestCommonMethods(data, "NSMutableInlineData", "mutable", 7);
	}

	@autoreleasepool {
		TestData *data = [[TestData alloc] initWithTestBytes:"foreign" count:7];

		TestCommonMethods(data, "TestData", "foreign", 7);
	}

	@autoreleasepool {
		TestMutableData *data = [[TestMutableData alloc] initWithTestBytes:"fallback" count:8];

		TestCommonMethods(data, "TestMutableData", "fallback", 8);
	}
}

static void
TestCopyOnWrite(void)
{
	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:"hello" count:5];
		NSMutableData *mutable = [data mutableCopy];
		void const *sharedBytes = data.bytes;

		TEST(mutable.bytes == sharedBytes);
		[mutable appendBytes:"!" count:1];
		TEST(data.bytes == sharedBytes);
		TEST_BYTES_EQ(data.bytes, "hello", 5);
		TEST(mutable.bytes != sharedBytes);
		TEST_BYTES_EQ(mutable.bytes, "hello!", 6);
	}

	@autoreleasepool {
		NSMutableData *mutable = [[NSMutableData alloc] initWithBytes:"AAAA" count:4];
		NSData *snapshot = [mutable copy];
		char *bytes;

		TEST(snapshot.bytes == mutable.bytes);
		bytes = mutable.mutableBytes;
		TEST(snapshot.bytes != mutable.bytes);
		bytes[0] = 'B';
		TEST_BYTES_EQ(snapshot.bytes, "AAAA", 4);
		TEST_BYTES_EQ(mutable.bytes, "BAAA", 4);
	}

	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:"shared bytes" count:12];
		NSMutableData *mutable = [data mutableCopy];
		NSData *roundTrip = [mutable copy];

		TEST(roundTrip.bytes == data.bytes);
		TEST([roundTrip isEqualToData:data]);
	}

	@autoreleasepool {
		NSMutableData *mutable = [[NSMutableData alloc] initWithBytes:"snapshot" count:8];
		NSData *full = [mutable subdataWithRange:NSRangeMake(0, mutable.count)];

		TEST((id)full != (id)mutable);
		TEST(full.bytes == mutable.bytes);
		[mutable appendBytes:"!" count:1];
		TEST_BYTES_EQ(full.bytes, "snapshot", 8);
		TEST_EQ_UNSIGNED(full.count, 8);
	}
}

static void
TestAliasingAppends(void)
{
	/* An overlapping source and destination must work without growth. */
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithCapacity:16];

		data.count = 8;
		memcpy(data.mutableBytes, "abcdefgh", 8);
		data.count = 4;

		void const *const source = (char const *)data.bytes + 2;
		[data appendBytes:source count:4];
		TEST_BYTES_EQ(data.bytes, "abcdcdef", 8);
	}

	/* Growth must not leave an interior source pointer referring to the old allocation. */
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"01234567" count:8];
		void const *const oldBytes = data.bytes;
		void const *const source = (char const *)oldBytes + 2;

		[data appendBytes:source count:4];
		TEST(data.bytes != oldBytes);
		TEST_BYTES_EQ(data.bytes, "012345672345", 12);
	}

	/* Aliasing unused capacity matters too: realloc would invalidate this source even though it is past count. */
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithCapacity:16];

		data.count = 4;
		char *const storage = data.mutableBytes;
		memcpy(storage, "abcdEFGHIJKLMNOP", 16);

		[data appendBytes:storage + 3 count:13];
		TEST_BYTES_EQ(data.bytes, "abcddEFGHIJKLMNOP", 17);
	}

	/* A source may begin before foreign storage and extend into the represented bytes. */
	@autoreleasepool {
		__block unsigned deallocations = 0;
		char *const storage = malloc(12);
		memcpy(storage, "0123456789AB", 12);

		NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:storage + 4 count:4
			deallocator:^(void *ownedBytes, NSUInteger count) {
				TEST(ownedBytes == storage + 4);
				TEST_EQ_UNSIGNED(count, 4);
				++deallocations;
				free(storage);
			}];

		[data appendBytes:storage + 2 count:4];
		TEST_EQ_UNSIGNED(deallocations, 1);
		TEST_BYTES_EQ(data.bytes, "45672345", 8);
	}

	/* A foreign deallocator may invalidate a disjoint source in the same enclosing allocation. */
	@autoreleasepool {
		__block unsigned deallocations = 0;
		char *const storage = malloc(12);
		memcpy(storage, "0123456789AB", 12);

		NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:storage + 4 count:4
			deallocator:^(void *ownedBytes, NSUInteger count) {
				TEST(ownedBytes == storage + 4);
				TEST_EQ_UNSIGNED(count, 4);
				++deallocations;
				free(storage);
			}];

		[data appendBytes:storage count:4];
		TEST_EQ_UNSIGNED(deallocations, 1);
		TEST_BYTES_EQ(data.bytes, "45670123", 8);
	}

	/* -appendData: uses the same alias-safe primitive, including exact self-append. */
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"self" count:4];

		[data appendData:data];
		TEST_BYTES_EQ(data.bytes, "selfself", 8);
	}

	/* A distinct immutable snapshot may supply bytes from the receiver's shared buffer. */
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"shared" count:6];
		NSData *snapshot = [data copy];
		void const *const sharedBytes = data.bytes;

		[data appendData:snapshot];
		TEST(data.bytes != sharedBytes);
		TEST(snapshot.bytes == sharedBytes);
		TEST_BYTES_EQ(snapshot.bytes, "shared", 6);
		TEST_BYTES_EQ(data.bytes, "sharedshared", 12);
	}
}

static void
TestAliasingReplacements(void)
{
	/* Same-length replacement is a single overlap-safe move. */
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"abcdefgh" count:8];
		void const *const source = (char const *)data.bytes + 1;

		[data replaceBytesInRange:NSRangeMake(2, 4) withBytes:source count:4];
		TEST_BYTES_EQ(data.bytes, "abbcdegh", 8);
	}

	/* Shrinking copies the input before shifting a tail that contains the input bytes. */
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"0123456789" count:10];
		void const *const source = (char const *)data.bytes + 6;

		[data replaceBytesInRange:NSRangeMake(2, 5) withBytes:source count:2];
		TEST_BYTES_EQ(data.bytes, "0167789", 7);
	}

	/* Growing can overwrite an internal source during the tail shift even when capacity is already sufficient. */
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithCapacity:16];

		data.count = 8;
		memcpy(data.mutableBytes, "01234567", 8);
		void const *const oldBytes = data.bytes;
		void const *const source = (char const *)oldBytes + 4;

		[data replaceBytesInRange:NSRangeMake(2, 1) withBytes:source count:4];
		TEST(data.bytes != oldBytes);
		TEST_BYTES_EQ(data.bytes, "01456734567", 11);
	}

	/* Internal growth from an exact-fit allocation must not read through a pointer invalidated by realloc. */
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"01234567" count:8];
		void const *const oldBytes = data.bytes;
		void const *const source = (char const *)oldBytes + 4;

		[data replaceBytesInRange:NSRangeMake(2, 1) withBytes:source count:4];
		TEST(data.bytes != oldBytes);
		TEST_BYTES_EQ(data.bytes, "01456734567", 11);
	}

	/* A source may begin before foreign storage and extend into the represented bytes. */
	@autoreleasepool {
		__block unsigned deallocations = 0;
		char *const storage = malloc(12);
		memcpy(storage, "0123456789AB", 12);

		NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:storage + 4 count:4
			deallocator:^(void *ownedBytes, NSUInteger oldLength) {
				TEST(ownedBytes == storage + 4);
				TEST_EQ_UNSIGNED(oldLength, 4);
				++deallocations;
				free(storage);
			}];

		[data replaceBytesInRange:NSRangeMake(1, 2) withBytes:storage + 2 count:4];
		TEST_EQ_UNSIGNED(deallocations, 1);
		TEST_BYTES_EQ(data.bytes, "423457", 6);
	}

	/* Foreign cleanup may invalidate a disjoint source in the same enclosing allocation. */
	@autoreleasepool {
		__block unsigned deallocations = 0;
		char *const storage = malloc(12);
		memcpy(storage, "0123456789AB", 12);

		NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:storage + 4 count:4
			deallocator:^(void *ownedBytes, NSUInteger oldLength) {
				TEST(ownedBytes == storage + 4);
				TEST_EQ_UNSIGNED(oldLength, 4);
				++deallocations;
				free(storage);
			}];

		[data replaceBytesInRange:NSRangeMake(1, 2) withBytes:storage count:2];
		TEST_EQ_UNSIGNED(deallocations, 1);
		TEST_BYTES_EQ(data.bytes, "4017", 4);
	}

	/* A shared immutable snapshot keeps an internal source alive across the detach. */
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"abcdef" count:6];
		NSData *snapshot = [data copy];
		void const *const sharedBytes = snapshot.bytes;

		[data replaceBytesInRange:NSRangeMake(1, 2)
			withBytes:(char const *)snapshot.bytes + 3 count:3];
		TEST(data.bytes != sharedBytes);
		TEST(snapshot.bytes == sharedBytes);
		TEST_BYTES_EQ(snapshot.bytes, "abcdef", 6);
		TEST_BYTES_EQ(data.bytes, "adefdef", 7);
	}
}

static void
TestSubranges(void)
{
	@autoreleasepool {
		NSData *subrange;

		@autoreleasepool {
			NSData *parent = [NSData dataWithBytes:"ABCDEFGH" count:8];

			subrange = [parent subdataWithRange:NSRangeMake(2, 4)];
		}

		TEST_BYTES_EQ(subrange.bytes, "CDEF", 4);
	}

	@autoreleasepool {
		NSData *nested;

		@autoreleasepool {
			NSData *parent = [NSData dataWithBytes:"0123456789" count:10];
			NSData *first = [parent subdataWithRange:NSRangeMake(2, 6)];

			nested = [first subdataWithRange:NSRangeMake(1, 3)];
			TEST((char const *)nested.bytes == (char const *)parent.bytes + 3);
		}

		TEST_BYTES_EQ(nested.bytes, "345", 3);
	}

	@autoreleasepool {
		NSMutableData *parent = [[NSMutableData alloc] initWithBytes:"0123456789" count:10];
		NSData *subrange = [parent subdataWithRange:NSRangeMake(3, 4)];
		void const *sharedBytes = parent.bytes;

		TEST((char const *)subrange.bytes == (char const *)parent.bytes + 3);
		[parent appendBytes:"X" count:1];
		TEST(parent.bytes != sharedBytes);
		TEST_BYTES_EQ(subrange.bytes, "3456", 4);
	}

	@autoreleasepool {
		NSData *parent = [NSData dataWithBytes:"ABCDEFGH" count:8];
		NSData *subrange = [parent subdataWithRange:NSRangeMake(2, 4)];
		NSMutableData *mutable = [subrange mutableCopy];

		TEST(mutable.bytes != subrange.bytes);
		[mutable appendBytes:"!" count:1];
		TEST_BYTES_EQ(subrange.bytes, "CDEF", 4);
		TEST_BYTES_EQ(mutable.bytes, "CDEF!", 5);
	}
}

static void
TestMutableMethodsOnObject(NSMutableData *data)
{
	data.count = 6;
	TEST_EQ_UNSIGNED(data.count, 6);
	TEST_BYTES_EQ(data.bytes, "abc\0\0\0", 6);

	data.count = 2;
	TEST_BYTES_EQ(data.bytes, "ab", 2);
	[data increaseCountBy:2];
	TEST_BYTES_EQ(data.bytes, "ab\0\0", 4);

	[data setData:[NSData dataWithBytes:"0123456789" count:10]];
	[data replaceBytesInRange:NSRangeMake(2, 3) withBytes:"AB" count:2];
	TEST_BYTES_EQ(data.bytes, "01AB56789", 9);
	[data replaceBytesInRange:NSRangeMake(2, 2) withBytes:"WXYZ" count:4];
	TEST_BYTES_EQ(data.bytes, "01WXYZ56789", 11);
	[data replaceBytesInRange:NSRangeMake(0, 2) withBytes:"__"];
	TEST_BYTES_EQ(data.bytes, "__WXYZ56789", 11);

	[data resetBytesInRange:NSRangeMake(2, 4)];
	TEST_BYTES_EQ(data.bytes, "__\0\0\0\0\x35\x36\x37\x38\x39", 11);

	[data setData:[NSData dataWithBytes:"ab" count:2]];
	[data appendData:[NSData dataWithBytes:"cd" count:2]];
	[data appendData:data];
	TEST_BYTES_EQ(data.bytes, "abcdabcd", 8);

	[data setData:data];
	TEST_BYTES_EQ(data.bytes, "abcdabcd", 8);
}

static void
TestMutableMethods(void)
{
	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"abc" count:3];

		TestMutableMethodsOnObject(data);
	}

	@autoreleasepool {
		TestMutableData *data = [[TestMutableData alloc] initWithTestBytes:"abc" count:3];

		TestMutableMethodsOnObject(data);
	}

	@autoreleasepool {
		NSData *source = [NSData dataWithBytes:"0123456789" count:10];
		NSMutableData *data = [source mutableCopy];
		void const *sharedBytes = source.bytes;

		[data replaceBytesInRange:NSRangeMake(2, 3) withBytes:"AB" count:2];
		TEST(data.bytes != sharedBytes);
		TEST_BYTES_EQ(data.bytes, "01AB56789", 9);
		TEST_BYTES_EQ(source.bytes, "0123456789", 10);
	}

	@autoreleasepool {
		NSData *source = [NSData dataWithBytes:"old data here" count:13];
		NSMutableData *data = [source mutableCopy];
		void const *sharedBytes = source.bytes;

		[data setData:[NSData dataWithBytes:"new" count:3]];
		TEST(data.bytes != sharedBytes);
		TEST_BYTES_EQ(data.bytes, "new", 3);
		TEST_BYTES_EQ(source.bytes, "old data here", 13);
	}

	@autoreleasepool {
		char borrowed[] = "borrowed";
		NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:borrowed count:8 freeWhenDone:false];
		char *mutableBytes = data.mutableBytes;

		TEST((void *)mutableBytes != (void *)borrowed);
		mutableBytes[0] = 'B';
		TEST_BYTES_EQ(borrowed, "borrowed", 8);
		TEST_BYTES_EQ(data.bytes, "Borrowed", 8);
	}

	@autoreleasepool {
		__block unsigned deallocations = 0;
		void *bytes = malloc(4);
		memcpy(bytes, "HOTS", 4);

		@autoreleasepool {
			NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:bytes count:4
				deallocator:^(void *ownedBytes, NSUInteger count) {
					TEST_EQ_UNSIGNED(count, 4);
					++deallocations;
					free(ownedBytes);
				}];

			[data appendBytes:"!" count:1];
			TEST_EQ_UNSIGNED(deallocations, 1);
			TEST_BYTES_EQ(data.bytes, "HOTS!", 5);
		}

		TEST_EQ_UNSIGNED(deallocations, 1);
	}
}

static uint64_t RandomState = UINT64_C(0x9e3779b97f4a7c15);

[[clang::no_sanitize("integer")]]
static uint64_t
NextRandom(void)
{
	RandomState ^= RandomState << 13;
	RandomState ^= RandomState >> 7;
	RandomState ^= RandomState << 17;

	return RandomState;
}

static NSRange
ReferenceRange(unsigned char const *haystack, unsigned char const *needle, NSUInteger needleCount,
	NSDataSearchOptions options, NSRange range)
{
	bool const backwards = (options & NSDataSearchBackwards) != 0;
	bool const anchored = (options & NSDataSearchAnchored) != 0;
	NSUInteger low;
	NSUInteger high;

	if (needleCount == 0)
		return NSRangeMake(backwards ? NSRangeMax(range) : range.location, 0);
	if (needleCount > range.length)
		return NSRangeMake(NSNotFound, 0);

	low = range.location;
	high = NSRangeMax(range) - needleCount;

	if (anchored) {
		NSUInteger const offset = backwards ? high : low;

		return memcmp(haystack + offset, needle, needleCount) == 0 ?
			NSRangeMake(offset, needleCount) : NSRangeMake(NSNotFound, 0);
	}

	if (backwards) {
		for (NSUInteger offset = high; ; --offset) {
			if (memcmp(haystack + offset, needle, needleCount) == 0)
				return NSRangeMake(offset, needleCount);
			if (offset == low)
				break;
		}
	} else {
		for (NSUInteger offset = low; offset <= high; ++offset)
			if (memcmp(haystack + offset, needle, needleCount) == 0)
				return NSRangeMake(offset, needleCount);
	}

	return NSRangeMake(NSNotFound, 0);
}

static NSData *
SearchData(unsigned char const *bytes, NSUInteger count, unsigned variant)
{
	switch (variant % 4) {
	case 0:
		return [NSData dataWithBytes:bytes count:count];
	case 1:
		return [[NSMutableData alloc] initWithBytes:bytes count:count];
	case 2: {
		NSMutableData *parent = [[NSMutableData alloc] initWithCount:count + 2];

		memcpy((unsigned char *)parent.mutableBytes + 1, bytes, count);
		return [parent subdataWithRange:NSRangeMake(1, count)];
	}
	default:
		return [[TestData alloc] initWithTestBytes:bytes count:count];
	}
}

static void
TestSearches(void)
{
	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:"abcabcabc" count:9];
		NSData *needle = [NSData dataWithBytes:"abc" count:3];

		TestRange([data rangeOfData:needle options:NSDataSearchDefault range:NSRangeMake(0, 9)], 0, 3);
		TestRange([data rangeOfData:needle options:NSDataSearchBackwards range:NSRangeMake(0, 9)], 6, 3);
		TestRange([data rangeOfData:needle options:NSDataSearchAnchored range:NSRangeMake(1, 8)], NSNotFound, 0);
		TestRange([data rangeOfData:needle options:(NSDataSearchOptions)(NSDataSearchAnchored | NSDataSearchBackwards)
			range:NSRangeMake(0, 9)], 6, 3);
		TestRange([data rangeOfData:[NSData data] options:NSDataSearchDefault range:NSRangeMake(2, 5)], 2, 0);
		TestRange([data rangeOfData:[NSData data] options:NSDataSearchBackwards range:NSRangeMake(2, 5)], 7, 0);
	}

	for (unsigned iteration = 0; iteration < 20000; ++iteration)
		@autoreleasepool {
			unsigned char haystack[512];
			unsigned char needle[40];
			NSUInteger const haystackCount = (NSUInteger)(NextRandom() % 512) + 1;
			NSUInteger const needleCount = (NSUInteger)(NextRandom() % 40);
			unsigned const alphabet = (unsigned)(NextRandom() % 4) + 2;
			NSUInteger location;
			NSUInteger length;
			NSDataSearchOptions options;
			NSData *data;
			NSData *needleData;
			NSRange actual;
			NSRange expected;

			for (NSUInteger index = 0; index < haystackCount; ++index)
				haystack[index] = (unsigned char)('a' + NextRandom() % alphabet);
			for (NSUInteger index = 0; index < needleCount; ++index)
				needle[index] = (unsigned char)('a' + NextRandom() % alphabet);

			if (needleCount <= haystackCount && needleCount > 0 && (NextRandom() & 3) == 0) {
				NSUInteger const source = (NSUInteger)(NextRandom() % (haystackCount - needleCount + 1));

				memcpy(needle, haystack + source, needleCount);
			}

			location = (NSUInteger)(NextRandom() % (haystackCount + 1));
			length = (NSUInteger)(NextRandom() % (haystackCount - location + 1));
			options = (NSDataSearchOptions)(NextRandom() &
				(NSDataSearchBackwards | NSDataSearchAnchored));
			data = SearchData(haystack, haystackCount, iteration);
			needleData = [NSData dataWithBytes:needle count:needleCount];
			actual = [data rangeOfData:needleData options:options range:NSRangeMake(location, length)];
			expected = ReferenceRange(haystack, needle, needleCount, options, NSRangeMake(location, length));

			TEST_EQ_UNSIGNED(actual.location, expected.location);
			TEST_EQ_UNSIGNED(actual.length, expected.length);
		}
}

static void
TestHashInvalidation(void)
{
	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:"hashme!!" count:8];
		NSUInteger const originalHash = data.hash;
		NSMutableData *mutable = [data mutableCopy];

		TEST_EQ_UNSIGNED(mutable.hash, originalHash);
		[mutable appendBytes:"X" count:1];
		TEST_EQ_UNSIGNED(data.hash, originalHash);
		TEST_NE(mutable.hash, originalHash);
	}

	@autoreleasepool {
		NSMutableData *data = [[NSMutableData alloc] initWithBytes:"mutable" count:7];
		NSUInteger const originalHash = data.hash;
		char *bytes = data.mutableBytes;

		bytes[0] = 'M';
		TEST_NE(data.hash, originalHash);
		TEST([data isEqualToData:[NSData dataWithBytes:"Mutable" count:7]]);
	}
}

int
main(void)
{
	TestEveryRepresentation();
	TestCopyOnWrite();
	TestAliasingAppends();
	TestAliasingReplacements();
	TestSubranges();
	TestMutableMethods();
	TestSearches();
	TestHashInvalidation();

	return TestFinish();
}

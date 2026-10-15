#import "Corpus.h"
#import "Test.h"

#include <stdint.h>

@interface NSNumberForeignDouble : NSNumber

+ (instancetype)numberWithValue:(double)value;

@end

@implementation NSNumberForeignDouble {
	double _value;
}

+ (instancetype)numberWithValue:(double)value
{
	NSNumberForeignDouble *number = [self alloc];
	number->_value = value;
	return number;
}

- (char const *)objCType
{
	return @encode(double);
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	if (size != sizeof(_value))
		abort();

	__builtin_memcpy_inline(value, &_value, sizeof(_value));
}

@end

static void
TestPair(NSNumberFixture const *fixture, size_t index, NSNumberFixture const *otherFixture, size_t otherIndex,
	NSUInteger hash, NSUInteger otherHash)
{
	NSNumber *number = fixture->number;
	NSNumber *otherNumber = otherFixture->number;
	NSComparisonResult const expected = NSNumberFixtureCompareValues(fixture->value, otherFixture->value);
	NSComparisonResult const actual = [number compare:otherNumber];
	bool const expectedEqual = expected == NSOrderedSame;
	bool const equalToNumber = [number isEqualToNumber:otherNumber];
	bool const equalAsObject = [number isEqual:otherNumber];
	char const *source = NSNumberFixtureSourceName(fixture->source);
	char const *otherSource = NSNumberFixtureSourceName(otherFixture->source);

	TESTF(actual == expected, "%zu/%s compare:%zu/%s: got %ld, expected %ld", index, source,
		otherIndex, otherSource, (long)actual, (long)expected);
	TESTF(actual == NSOrderedAscending || actual == NSOrderedSame || actual == NSOrderedDescending,
		"%zu/%s compare:%zu/%s returned non-canonical result %ld", index, source,
		otherIndex, otherSource, (long)actual);
	TESTF(equalToNumber == expectedEqual, "%zu/%s isEqualToNumber:%zu/%s: got %d, expected %d", index,
		source, otherIndex, otherSource, (int)equalToNumber, (int)expectedEqual);
	TESTF(equalAsObject == expectedEqual, "%zu/%s isEqual:%zu/%s: got %d, expected %d", index,
		source, otherIndex, otherSource, (int)equalAsObject, (int)expectedEqual);
	TESTF((actual == NSOrderedSame) == equalToNumber,
		"%zu/%s compare: and isEqualToNumber: disagree for %zu/%s", index, source, otherIndex, otherSource);
	if (expectedEqual)
		TESTF(hash == otherHash, "%zu/%s and %zu/%s are equal but hash differently", index, source,
			otherIndex, otherSource);
}

int
main(void)
{
	@autoreleasepool {
		NSNumberFixture fixtures[NSNumberFixtureMaximumCount] = {};
		NSUInteger hashes[NSNumberFixtureMaximumCount] = { 0 };
		size_t const count = NSNumberBuildFixtureCorpus(fixtures);
		double const foreignValues[] = {
			-DBL_MAX, -0x1p64, -0x1p63, -0x1p53, -1.5, -DBL_TRUE_MIN, -0.0,
			0.0, DBL_TRUE_MIN, 0.5, 0x1p53, 0x1p63, 0x1p64, DBL_MAX
		};
		NSNumberFixture foreignFixtures[sizeof(foreignValues) / sizeof(foreignValues[0])] = {};
		NSUInteger foreignHashes[sizeof(foreignValues) / sizeof(foreignValues[0])] = { 0 };
		size_t foreignCount = 0;

		TESTF(count > 300, "corpus unexpectedly contains only %zu fixtures", count);
		for (size_t i = 0; i < count; ++i)
			hashes[i] = fixtures[i].number.hash;
		for (size_t i = 0; i < sizeof(foreignValues) / sizeof(foreignValues[0]); ++i) {
			NSNumberFixtureAddFloating(foreignFixtures, &foreignCount, NSNumberFixtureSourceDouble,
				@encode(double)[0], foreignValues[i],
				[NSNumberForeignDouble numberWithValue:foreignValues[i]]);
			foreignHashes[i] = foreignFixtures[i].number.hash;
		}

		for (size_t i = 0; i < count; ++i) {
			for (size_t j = 0; j < count; ++j)
				TestPair(&fixtures[i], i, &fixtures[j], j, hashes[i], hashes[j]);

			for (size_t j = 0; j < foreignCount; ++j) {
				TestPair(&fixtures[i], i, &foreignFixtures[j], count + j, hashes[i], foreignHashes[j]);
				TestPair(&foreignFixtures[j], count + j, &fixtures[i], i, foreignHashes[j], hashes[i]);
			}
		}
	}

	return TestFinish();
}

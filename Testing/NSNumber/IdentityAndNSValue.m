#import "Corpus.h"
#import "Test.h"

#import <objc/runtime.h>

static NSValue *
ValueWithSameTypedBytes(NSNumberFixture const *fixture)
{
	switch (fixture->source) {
	case NSNumberFixtureSourceChar: {
		char const value = (char)fixture->value.v.signedValue;
		return [NSValue valueWithBytes:&value objCType:@encode(char)];
	}
	case NSNumberFixtureSourceUnsignedChar: {
		unsigned char const value = (unsigned char)fixture->value.v.unsignedValue;
		return [NSValue valueWithBytes:&value objCType:@encode(unsigned char)];
	}
	case NSNumberFixtureSourceShort: {
		short const value = (short)fixture->value.v.signedValue;
		return [NSValue valueWithBytes:&value objCType:@encode(short)];
	}
	case NSNumberFixtureSourceUnsignedShort: {
		unsigned short const value = (unsigned short)fixture->value.v.unsignedValue;
		return [NSValue valueWithBytes:&value objCType:@encode(unsigned short)];
	}
	case NSNumberFixtureSourceInt: {
		int const value = (int)fixture->value.v.signedValue;
		return [NSValue valueWithBytes:&value objCType:@encode(int)];
	}
	case NSNumberFixtureSourceUnsignedInt: {
		unsigned int const value = (unsigned int)fixture->value.v.unsignedValue;
		return [NSValue valueWithBytes:&value objCType:@encode(unsigned int)];
	}
	case NSNumberFixtureSourceLong:
	case NSNumberFixtureSourceInteger: {
		long const value = (long)fixture->value.v.signedValue;
		return [NSValue valueWithBytes:&value objCType:@encode(long)];
	}
	case NSNumberFixtureSourceUnsignedLong:
	case NSNumberFixtureSourceUnsignedInteger: {
		unsigned long const value = (unsigned long)fixture->value.v.unsignedValue;
		return [NSValue valueWithBytes:&value objCType:@encode(unsigned long)];
	}
	case NSNumberFixtureSourceLongLong: {
		long long const value = (long long)fixture->value.v.signedValue;
		return [NSValue valueWithBytes:&value objCType:@encode(long long)];
	}
	case NSNumberFixtureSourceUnsignedLongLong: {
		unsigned long long const value = (unsigned long long)fixture->value.v.unsignedValue;
		return [NSValue valueWithBytes:&value objCType:@encode(unsigned long long)];
	}
	case NSNumberFixtureSourceBool: {
		bool const value = fixture->value.v.unsignedValue != 0;
		return [NSValue valueWithBytes:&value objCType:@encode(bool)];
	}
	case NSNumberFixtureSourceFloat: {
		float const value = (float)fixture->value.v.floatingValue;
		return [NSValue valueWithBytes:&value objCType:@encode(float)];
	}
	case NSNumberFixtureSourceDouble: {
		double const value = fixture->value.v.floatingValue;
		return [NSValue valueWithBytes:&value objCType:@encode(double)];
	}
	}
}

int
main(void)
{
	@autoreleasepool {
		NSNumberFixture fixtures[NSNumberFixtureMaximumCount] = {};
		size_t const count = NSNumberBuildFixtureCorpus(fixtures);
		SEL const unsafeObjectSelector = sel_registerName("nonretainedObjectValue");

		TESTF(count > 300, "corpus unexpectedly contains only %zu fixtures", count);
		for (size_t i = 0; i < count; ++i) {
			NSNumber *number = fixtures[i].number;
			NSValue *value = ValueWithSameTypedBytes(&fixtures[i]);
			id copy = [number copy];
			char const *source = NSNumberFixtureSourceName(fixtures[i].source);

			TESTF(copy == number, "%zu/%s copy did not return the immutable receiver", i, source);
			TESTF([number isEqual:value] == false, "%zu/%s NSNumber equals an NSValue with the same bytes", i,
				source);
			/* The reverse direction remains intentionally untested until NSValue class-gates -isEqualToValue:. */
			TESTF(number.hash != value.hash,
				"%zu/%s NSNumber and same-byte NSValue use the same hash", i, source);
			TESTF([number respondsToSelector:unsafeObjectSelector] == false,
				"%zu/%s responds to removed -nonretainedObjectValue", i, source);
		}
	}

	return TestFinish();
}

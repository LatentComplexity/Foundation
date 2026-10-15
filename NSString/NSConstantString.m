
#import <FoundationPrivate/NSString/NSString.h>

@implementation NSConstantString {
	unsigned int _flags;
	unsigned int _length;
	unsigned int _size;
	unsigned int _hash;
	union {
		char const *b;
		unichar const *u;
	} _bytes;
}

/*
 * Constant strings have a 32-bit length field. This creates a type mismatch between our constant string class and
 * NSString, so we access the instance variables directly.
 */

[[clang::always_inline]]
static inline bool
ConstantStringIsASCII(NSConstantString *constant)
{
	return constant->_flags == 0;
}

- (NSUInteger)length
{
	return (NSUInteger)_length;
}

- (unichar)characterAtIndex:(NSUInteger)index
{
	if (index >= _length)
		_NSRaiseException(MethodContext, NSRangeException, @"index out of bounds.");

	return ConstantStringIsASCII(self) ? (unichar)_bytes.b[index] : _bytes.u[index];
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)range
{
	if (_length == 0 || range.length == 0)
		return;

	if (buffer == nullptr || NSRangeMax(range) > (NSUInteger)_length)
		abort();

	if (ConstantStringIsASCII(self))
		for (NSUInteger i = 0; i < range.length; ++i)
			buffer[i] = (unichar)_bytes.b[i];
	else {
		if (__builtin_mul_overflow(range.length, sizeof(unichar), &range.length))
			abort();

		memcpy(buffer, _bytes.u + range.location, range.length);
	}
}

@end

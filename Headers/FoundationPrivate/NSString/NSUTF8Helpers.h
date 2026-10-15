
#include <Foundation/NSObjCRuntime.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Walk a validated UTF-8 buffer once, returning its length in UTF-16 code units. Each byte that is not a continuation
 * (10xxxxxx) starts one code point and contributes one unit; a four-byte lead (>= 0xF0) encodes an astral code point,
 * which UTF-16 represents as a surrogate pair, so it contributes one extra unit. Note that the result equals
 * byteLength iff the buffer is pure ASCII.
 *
 * Precondition: the first byteLength bytes were validated as well-formed UTF-8.
 */
[[clang::always_inline]]
static inline NSUInteger
NSUTF8CountUTF16Units(void const *bytes, NSUInteger byteLength)
{
	unsigned char const *p = bytes;
	NSUInteger units = 0;

	for (NSUInteger i = 0; i < byteLength; ++i) {
		unsigned char c = p[i];

		if ((c & 0xC0) != 0x80)			/* not a continuation byte: a code point begins */
			++units;
		if (c >= 0xF0)				/* four-byte lead: astral -> surrogate pair */
			++units;
	}

	return units;
}

/*
 * Decode a validated UTF-8 buffer into host-order UTF-16, writing each code unit into the out pointer in order.
 * A basic multilingual plane code point yields one unit; an astral code point (four-byte sequence) yields a surrogate
 * pair. out must hold NSUTF8CountUTF16Units(bytes, byteLength) units, and the input is assumed already valid.
 */
[[clang::always_inline]]
static inline void
ConvertUTF8ToUTF16(unichar *out, void const *bytes, NSUInteger byteLength)
{
	unsigned char const *p = bytes;
	NSUInteger u = 0;
	NSUInteger i = 0;

	while (i < byteLength) {
		unsigned char c = p[i];
		unsigned int cp;
		NSUInteger seqLength;

		if (c < 0x80) {
			cp = c;
			seqLength = 1;
		} else if ((c & 0xE0) == 0xC0) {
			cp = c & 0x1F;
			seqLength = 2;
		} else if ((c & 0xF0) == 0xE0) {
			cp = c & 0x0F;
			seqLength = 3;
		} else {
			cp = c & 0x07;
			seqLength = 4;
		}

		for (NSUInteger k = 1; k < seqLength; ++k)
			cp = (cp << 6) | (p[i + k] & 0x3F);

		if (cp < 0x10000) {
			out[u++] = (unichar)cp;
		} else {
			cp -= 0x10000;
			out[u++] = (unichar)(0xD800 + (cp >> 10));	/* high surrogate */
			out[u++] = (unichar)(0xDC00 + (cp & 0x3FF));	/* low surrogate */
		}

		i += seqLength;
	}
}

NS_ASSUME_NONNULL_END

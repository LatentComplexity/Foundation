
/*
 * Streaming and one-shot implementations of SipHash-1-3.
 */

#import <Foundation/NSObjCRuntime.h>

NS_ASSUME_NONNULL_BEGIN

enum NSSipHashDefaultState : NSUInteger {
	v0DefaultState = 0x736f6d6570736575,
	v1DefaultState = 0x646f72616e646f6d,
	v2DefaultState = 0x6c7967656e657261,
	v3DefaultState = 0x7465646279746573
};

#define SipRound \
	do { \
		c->v0 += c->v1; \
		c->v1 = __builtin_rotateleft64(c->v1, 13); \
		c->v1 ^= c->v0; \
		c->v0 = __builtin_rotateleft64(c->v0, 32); \
		c->v2 += c->v3; \
		c->v3 = __builtin_rotateleft64(c->v3, 16); \
		c->v3 ^= c->v2; \
		c->v0 += c->v3; \
		c->v3 = __builtin_rotateleft64(c->v3, 21); \
		c->v3 ^= c->v0; \
		c->v2 += c->v1; \
		c->v1 = __builtin_rotateleft64(c->v1, 17); \
		c->v1 ^= c->v2; \
		c->v2 = __builtin_rotateleft64(c->v2, 32); \
	} while (false)

typedef struct NSSipHashContext {
	unsigned long v0;
	unsigned long v1;
	unsigned long v2;
	unsigned long v3;
	NSUInteger buffer;
	NSUInteger bufferByteLength;
	NSUInteger totalLength;
} NSSipHashContext;

/* TODO: rename to NSSipHashWithContextInit(), or rename NSSipHashWithContextFinalize to NSSipHashContextFinalize(). */
/* TODO: I can't make up my mind which one yet. */
[[clang::always_inline]]
static inline void
NSSipHashContextInit(NSSipHashContext *const c, unsigned const __int128 key)
{
	c->v0 = v0DefaultState ^ (unsigned long)key;
	c->v1 = v1DefaultState ^ (unsigned long)(key >> 64);
	c->v2 = v2DefaultState ^ (unsigned long)key;
	c->v3 = v3DefaultState ^ (unsigned long)(key >> 64);
	c->buffer = 0;
	c->bufferByteLength = 0;
	c->totalLength = 0;
}

[[clang::always_inline]]
[[clang::no_sanitize("integer")]]
static inline void
NSSipHashWithContext(NSSipHashContext *const c, void const *const bytes, NSUInteger length)
{
	unsigned char const *b = (unsigned char const *)bytes;
	NSUInteger bufferBytesLeft, incomingBytes, fillBy;

	while (length != 0) {
		incomingBytes = 0;
		bufferBytesLeft = sizeof(NSUInteger) - c->bufferByteLength;
		fillBy = MIN(bufferBytesLeft, length);

		switch (fillBy) {
		case 8:
			incomingBytes |= (NSUInteger)b[7] << 56;
			[[fallthrough]];
		case 7:
			incomingBytes |= (NSUInteger)b[6] << 48;
			[[fallthrough]];
		case 6:
			incomingBytes |= (NSUInteger)b[5] << 40;
			[[fallthrough]];
		case 5:
			incomingBytes |= (NSUInteger)b[4] << 32;
			[[fallthrough]];
		case 4:
			incomingBytes |= (NSUInteger)b[3] << 24;
			[[fallthrough]];
		case 3:
			incomingBytes |= (NSUInteger)b[2] << 16;
			[[fallthrough]];
		case 2:
			incomingBytes |= (NSUInteger)b[1] << 8;
			[[fallthrough]];
		case 1:
			incomingBytes |= (NSUInteger)b[0];
			[[fallthrough]];
		case 0:
			;
		}

		c->buffer |= incomingBytes << (64 - bufferBytesLeft * 8);
		c->bufferByteLength += fillBy;

		if (c->bufferByteLength == 8) {
			c->v3 ^= c->buffer;
			SipRound;
			c->v0 ^= c->buffer;
			c->buffer = 0;
			c->bufferByteLength = 0;
		}

		b += fillBy;
		length -= fillBy;
		c->totalLength += fillBy;
	}
}

[[clang::always_inline]]
[[clang::no_sanitize("integer")]]
static inline void
NSSipHashWithContextFinalize(NSSipHashContext *const c, NSUInteger *const hash)
{
	c->buffer |= (c->totalLength & 0xFF) << 56;
	c->v3 ^= c->buffer;
	SipRound;
	c->v0 ^= c->buffer;
	c->v2 ^= 0xFF;
	SipRound;
	SipRound;
	SipRound;

	*hash = c->v0 ^ c->v1 ^ c->v2 ^ c->v3;
}

[[gnu::visibility("hidden")]]
[[clang::no_sanitize("integer")]]
NSUInteger
NSSipHash(void const *const _Nullable, NSUInteger, unsigned const __int128);

NS_ASSUME_NONNULL_END


#include <FoundationPrivate/Routines/NSSipHash.h>

/* Out of principle, I refuse to reuse SipRound and do: `NSSipHashContext ctx; NSSipHashContext *c = &ctx;` */
#undef SipRound
#define SipRound \
	do { \
		v0 += v1; \
		v1 = __builtin_rotateleft64(v1, 13); \
		v1 ^= v0; \
		v0 = __builtin_rotateleft64(v0, 32); \
		v2 += v3; \
		v3 = __builtin_rotateleft64(v3, 16); \
		v3 ^= v2; \
		v0 += v3; \
		v3 = __builtin_rotateleft64(v3, 21); \
		v3 ^= v0; \
		v2 += v1; \
		v1 = __builtin_rotateleft64(v1, 17); \
		v1 ^= v2; \
		v2 = __builtin_rotateleft64(v2, 32); \
	} while (false)

[[clang::no_sanitize("integer")]]
NSUInteger
NSSipHash(void const *const bytes, NSUInteger length, unsigned const __int128 key)
{
	unsigned char const *b = (unsigned char const *)bytes;

	NSUInteger v0 = v0DefaultState ^ (unsigned long)key;
	NSUInteger v1 = v1DefaultState ^ (unsigned long)(key >> 64);
	NSUInteger v2 = v2DefaultState ^ (unsigned long)key;
	NSUInteger v3 = v3DefaultState ^ (unsigned long)(key >> 64);

	/* Compress every whole eight-byte little-endian word of the message. */
	while (length >= sizeof(NSUInteger)) {
		NSUInteger eightbyte;
		__builtin_memcpy_inline(&eightbyte, b, sizeof(eightbyte));
		v3 ^= eightbyte;
		SipRound;
		v0 ^= eightbyte;
		b += sizeof(eightbyte);
		length -= sizeof(eightbyte);
	}

	/* Pack the 0 to 7 trailing bytes beneath the length byte. */
	NSUInteger lastBlock = (length & 0xFF) << 56;
	switch (length) {
	case 7:
		lastBlock |= (NSUInteger)b[6] << 48;
		[[fallthrough]];
	case 6:
		lastBlock |= (NSUInteger)b[5] << 40;
		[[fallthrough]];
	case 5:
		lastBlock |= (NSUInteger)b[4] << 32;
		[[fallthrough]];
	case 4:
		lastBlock |= (NSUInteger)b[3] << 24;
		[[fallthrough]];
	case 3:
		lastBlock |= (NSUInteger)b[2] << 16;
		[[fallthrough]];
	case 2:
		lastBlock |= (NSUInteger)b[1] << 8;
		[[fallthrough]];
	case 1:
		lastBlock |= (NSUInteger)b[0];
		[[fallthrough]];
	case 0:
		;
	}

	v3 ^= lastBlock;
	SipRound;
	v0 ^= lastBlock;
	v2 ^= 0xFF;
	SipRound;
	SipRound;
	SipRound;

	return v0 ^ v1 ^ v2 ^ v3;
}

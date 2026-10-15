
typedef enum NSByteOrder : bool {
	NSByteOrderLittleEndian = 0,
	NSByteOrderBigEndian = 1
} NSByteOrder;

[[clang::always_inline]]
static inline bool
NSByteOrderHost(void)
{
	union {
		int i;
		char b[sizeof(int)];
	} u;

	u.i = 1;
	return u.b[0] ? NSByteOrderLittleEndian : NSByteOrderBigEndian;
}

#ifndef NSByteOrderSwapShort
#define NSByteOrderSwapShort(x) ((short)__builtin_bswap16((unsigned short const)(x)))
#endif

#ifndef NSByteOrderSwapUnsignedShort
#define NSByteOrderSwapUnsignedShort(x) __builtin_bswap16((x))
#endif

#ifndef NSByteOrderSwapInt
#define NSByteOrderSwapInt(x) ((int)__builtin_bswap32((unsigned int const)(x)))
#endif

#ifndef NSByteOrderSwapUnsignedInt
#define NSByteOrderSwapUnsignedInt(x) __builtin_bswap32((x))
#endif

#ifndef NSByteOrderSwapLong
#define NSByteOrderSwapLong(x) ((long)__builtin_bswap64((unsigned long const)(x)))
#endif

#ifndef NSByteOrderSwapUnsignedLong
#define NSByteOrderSwapUnsignedLong(x) __builtin_bswap64((x))
#endif

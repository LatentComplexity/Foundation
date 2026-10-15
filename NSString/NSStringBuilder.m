
#import <FoundationPrivate/NSString/NSStringBuilder.h>
#import <FoundationPrivate/Routines/NSDoubleToDecimal.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wfloat-equal"
#pragma clang diagnostic ignored "-Wdouble-promotion"
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"

typedef enum NSStringBuilderEncoding : unsigned char {
	NSStringBuilderEncodingUTF8,
	NSStringBuilderEncodingUTF16
} NSStringBuilderEncoding;

typedef struct NSStringBuilderResult {
	union {
		char *utf8;
		unichar *utf16;
	} data;
	NSUInteger length;
	bool isASCII;
	NSStringBuilderEncoding encoding;
	char padding[6];
} NSStringBuilderResult;

enum {
	NSStringBuilderFlagMinus = 1 << 0,
	NSStringBuilderFlagPlus  = 1 << 1,
	NSStringBuilderFlagSpace = 1 << 2,
	NSStringBuilderFlagHash  = 1 << 3,
	NSStringBuilderFlagZero  = 1 << 4
};

enum {
	NSStringBuilderLenNone,
	NSStringBuilderLenChar,
	NSStringBuilderLenShort,
	NSStringBuilderLenLong,
	NSStringBuilderLenLongLong,
	NSStringBuilderLenIntMax,
	NSStringBuilderLenSize,
	NSStringBuilderLenPtrDiff,
	NSStringBuilderLenLongDouble
};

/*
 * The working output buffer. length and capacity are counts of elements (1-byte chars in UTF-8, 2-byte unichars in
 * UTF-16); the byte size of an element is derived from encoding. The same struct doubles as a scratch buffer for the
 * float formatters, where it is always used in UTF-8 (byte) mode to stage ASCII digit bodies.
 */
typedef struct NSStringBuilderBuffer {
	void *data;
	NSUInteger length;
	NSUInteger capacity;
	NSStringBuilderEncoding encoding;
	bool isASCII;
	char padding[6];
} NSStringBuilderBuffer;

/*
 * Decimal digit string with explicit length and exponent. digits is most-significant-first with no terminator;
 * ndigits is the count of valid bytes; exp10 is the scientific exponent of the leading digit (digits[0] sits in
 * the 10^exp10 place). Intermediate form between NSDoubleToDecimal's (sig, exp10) pair and the layout code.
 */
typedef struct NSStringBuilderDec {
	char digits[20];
	int ndigits;
	int exp10;
} NSStringBuilderDec;

[[clang::always_inline]]
static inline NSUInteger
NSStringBuilderElementSize(NSStringBuilderEncoding encoding)
{
	return encoding == NSStringBuilderEncodingUTF8 ? 1 : sizeof(unichar);
}

[[clang::always_inline]]
static inline void
NSStringBuilderGrow(NSStringBuilderBuffer *buf, NSUInteger additional)
{
	NSUInteger needed;
	NSUInteger newCap;
	NSUInteger byteCap;
	void *newData;

	if (__builtin_add_overflow(buf->length, additional, &needed))
		abort();

	if (needed <= buf->capacity)
		return;

	newCap = buf->capacity == 0 ? 128 : buf->capacity;
	while (newCap < needed)
		if (__builtin_mul_overflow(newCap, 2, &newCap))
			abort();

	if (__builtin_mul_overflow(newCap, NSStringBuilderElementSize(buf->encoding), &byteCap))
		abort();

	if ((newData = realloc(buf->data, byteCap)) == nullptr)
		abort();

	buf->data = newData;
	buf->capacity = newCap;
}

/*
 * Append one guaranteed-ASCII byte (signs, digits, prefixes like "0x", padding spaces/zeros, words like "nan"). In
 * UTF-8 it is stored verbatim; in UTF-16 it is widened to a code unit.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderAppendByte(NSStringBuilderBuffer *buf, char c)
{
	NSStringBuilderGrow(buf, 1);

	if (buf->encoding == NSStringBuilderEncodingUTF8)
		((char *)buf->data)[buf->length++] = c;
	else
		((unichar *)buf->data)[buf->length++] = (unichar)(unsigned char)c;
}

/*
 * Append one raw UTF-16 code unit. Only valid on a UTF-16 buffer; used by the code-point encoder for surrogate pairs.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderAppendUTF16Unit(NSStringBuilderBuffer *buf, unichar u)
{
	NSStringBuilderGrow(buf, 1);
	((unichar *)buf->data)[buf->length++] = u;
}

/*
 * Append one byte from an external source (the %s argument). In UTF-8 the byte passes through verbatim, preserving
 * NSLog's historical raw-byte behavior even for non-ASCII input; in UTF-16 it is widened as Latin-1. Clears isASCII
 * for any byte > 0x7F. For ASCII input this behaves identically to NSStringBuilderAppendByte().
 *
 * TO-DO: I dread the validation that will eventually have to take place for %s arguments. We should probably treat
 * %s as UTF-8 input instead of plain ASCII. Ugh.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderAppendExternalByte(NSStringBuilderBuffer *buf, unsigned char b)
{
	NSStringBuilderGrow(buf, 1);

	if (buf->encoding == NSStringBuilderEncodingUTF8)
		((char *)buf->data)[buf->length++] = (char)b;
	else
		((unichar *)buf->data)[buf->length++] = (unichar)b;

	if (b > 0x7F)
		buf->isASCII = false;
}

/*
 * Append a run of guaranteed-ASCII bytes by widening each one. Used for the hex prefix in integer output and to stage
 * ASCII bodies inside the float formatters' byte buffers.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderAppendBytes(NSStringBuilderBuffer *buf, char const *src, NSUInteger len)
{
	for (NSUInteger i = 0; i < len; ++i)
		NSStringBuilderAppendByte(buf, src[i]);
}

/*
 * Append a Unicode scalar in the buffer's encoding: UTF-8 emits 1-4 bytes, UTF-16 emits one code unit or a surrogate
 * pair. Clears isASCII for anything above 0x7F.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderAppendCodePoint(NSStringBuilderBuffer *buf, unsigned int codePoint)
{
	if (codePoint > 0x7F)
		buf->isASCII = false;

	if (buf->encoding == NSStringBuilderEncodingUTF8) {
		if (codePoint <= 0x7F)
			NSStringBuilderAppendByte(buf, (char)codePoint);
		else if (codePoint <= 0x7FF) {
			NSStringBuilderAppendByte(buf, (char)(0xC0 | (codePoint >> 6)));
			NSStringBuilderAppendByte(buf, (char)(0x80 | (codePoint & 0x3F)));
		} else if (codePoint <= 0xFFFF) {
			NSStringBuilderAppendByte(buf, (char)(0xE0 | (codePoint >> 12)));
			NSStringBuilderAppendByte(buf, (char)(0x80 | ((codePoint >> 6) & 0x3F)));
			NSStringBuilderAppendByte(buf, (char)(0x80 | (codePoint & 0x3F)));
		} else {
			NSStringBuilderAppendByte(buf, (char)(0xF0 | (codePoint >> 18)));
			NSStringBuilderAppendByte(buf, (char)(0x80 | ((codePoint >> 12) & 0x3F)));
			NSStringBuilderAppendByte(buf, (char)(0x80 | ((codePoint >> 6) & 0x3F)));
			NSStringBuilderAppendByte(buf, (char)(0x80 | (codePoint & 0x3F)));
		}
	} else {
		if (codePoint <= 0xFFFF)
			NSStringBuilderAppendUTF16Unit(buf, (unichar)codePoint);
		else {
			unsigned int v = codePoint - 0x10000U;

			NSStringBuilderAppendUTF16Unit(buf, (unichar)(0xD800U + (v >> 10)));
			NSStringBuilderAppendUTF16Unit(buf, (unichar)(0xDC00U + (v & 0x3FFU)));
		}
	}
}

/*
 * Read one code point out of an NSString at *ip, combining a surrogate pair when present, and append it. Advances *ip
 * past the consumed code unit(s). A lone surrogate becomes U+FFFD.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderAppendUnichar(NSStringBuilderBuffer *buf, NSString *src, NSUInteger *ip, NSUInteger len)
{
	unichar c, c2;
	unsigned int codePoint;

	c = [src characterAtIndex:*ip];

	if (c >= 0xD800 && c <= 0xDBFF) {
		if (*ip + 1 >= len) {
			NSStringBuilderAppendCodePoint(buf, 0xFFFD);
			++*ip;
			return;
		}

		c2 = [src characterAtIndex:*ip + 1];
		if (c2 >= 0xDC00 && c2 <= 0xDFFF) {
			codePoint = 0x10000U + (((unsigned int)c - 0xD800U) << 10) + ((unsigned int)c2 - 0xDC00U);
			NSStringBuilderAppendCodePoint(buf, codePoint);
			*ip += 2;
			return;
		}
	}

	if (c >= 0xD800 && c <= 0xDFFF) {
		NSStringBuilderAppendCodePoint(buf, 0xFFFD);
		++*ip;
		return;
	}

	NSStringBuilderAppendCodePoint(buf, c);
	++*ip;
}

/* Append a whole NSString (used by %@). */
[[clang::always_inline]]
static inline void
NSStringBuilderAppendString(NSStringBuilderBuffer *buf, NSString *str)
{
	NSUInteger len, i;

	len = str.length;
	i = 0;

	while (i < len)
		NSStringBuilderAppendUnichar(buf, str, &i, len);
}

/*
 * Copy every element of src into dst. Both must share an encoding (the caller stages into a scratch buffer initialized
 * with the destination's encoding). Propagates a cleared isASCII.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderAppendRun(NSStringBuilderBuffer *dst, NSStringBuilderBuffer const *src)
{
	NSUInteger elem;

	if (!src->isASCII)
		dst->isASCII = false;

	/* Guard the empty case: src->data may be null, and memcpy(dst, null, 0) is undefined behavior. */
	/* TO-DO: Not in C23 it ain't! Eh, we'll keep this here. */
	if (src->length == 0)
		return;

	NSStringBuilderGrow(dst, src->length);
	elem = NSStringBuilderElementSize(dst->encoding);
	__builtin_memcpy((char *)dst->data + dst->length * elem, src->data, src->length * elem);
	dst->length += src->length;
}

[[clang::always_inline]]
static inline void
NSStringBuilderPad(NSStringBuilderBuffer *buf, char pad, NSUInteger count)
{
	for (NSUInteger i = 0; i < count; ++i)
		NSStringBuilderAppendByte(buf, pad);
}

/*
 * Generic "emit a fully-assembled value with the right padding" helper. The caller hands us three pieces in display
 * order: an optional sign byte, an optional prefix (e.g. "0x"), and a body (digits, words like "nan", or a raw %s
 * argument) and we figure out where the padding goes. The final layout is:
 *
 *   [ left-pad spaces ] [ sign ] [ prefix ] [ zero pad ] [ body ] [ right-pad spaces ]
 *
 * Only one of the pad regions is ever non-empty:
 *   - With the '-' flag, padding goes on the right (left-justified).
 *   - With the '0' flag and no '-', padding becomes zeros placed between prefix and body.
 *   - Otherwise, padding is spaces on the left (right-justified, the default).
 *
 * Sign and prefix are ASCII and widen via AppendByte; the body is appended via AppendExternalByte so that the same
 * path serves both ASCII-generated bodies (floats, %p, %c) and the raw bytes of a %s argument.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderEmitPadded(NSStringBuilderBuffer *buf, char sign, char const * _Nullable prefix, int prefixLen,
		char const *body, NSUInteger bodyLen, int flags, int width, bool zeroPadBody)
{
	NSUInteger total;
	NSUInteger pad;

	/* The width sub-specifier applies to the whole output, not just the body, so include sign and prefix. */
	total = (NSUInteger)(sign ? 1 : 0) + (NSUInteger)prefixLen + bodyLen;
	pad = (width > 0 && (NSUInteger)width > total) ? (NSUInteger)width - total : 0;

	/* Default right-justification: space pad before everything else. Suppressed by '-' or by zero padding. */
	if (!(flags & NSStringBuilderFlagMinus) && !zeroPadBody)
		NSStringBuilderPad(buf, ' ', pad);

	/* Sign, then prefix, in that order: the prefix always sits between the sign and the digits. */
	if (sign)
		NSStringBuilderAppendByte(buf, sign);

	for (int k = 0; k < prefixLen; ++k)
		NSStringBuilderAppendByte(buf, prefix[k]);

	/* Zero padding (when the '0' flag is honored) goes after the prefix and immediately before the body. */
	if (zeroPadBody)
		NSStringBuilderPad(buf, '0', pad);

	for (NSUInteger k = 0; k < bodyLen; ++k)
		NSStringBuilderAppendExternalByte(buf, (unsigned char)body[k]);

	/* Left-justified output ('-' flag): trailing spaces fill out to the requested width. */
	if (flags & NSStringBuilderFlagMinus)
		NSStringBuilderPad(buf, ' ', pad);
}

[[clang::always_inline]]
static inline void
NSStringBuilderFormatInt(NSStringBuilderBuffer *buf, unsigned long long value, bool negative, unsigned int base,
		bool uppercase, int flags, int width, int precision)
{
	/*
	 * Worst case for the digit count: a 64-bit unsigned long long in base 8 needs 22 characters
	 * (1777777777777777777777). The '#' flag in octal may add one more leading '0'. 24 leaves a comfortable
	 * margin. Note that this buffer holds only the digits produced by the conversion itself; precision-driven
	 * leading zeros are emitted directly into the output buffer further down, since precision is unbounded
	 * and could otherwise overflow this array.
	 */
	char digits[24];
	int ndigits;
	int precisionZeros;
	char const *digitset;
	char sign;
	char prefix[2] = { 0 };
	int prefixLen;
	bool precisionGiven;
	bool valueIsZero;
	NSUInteger total, pad;
	bool zeroPad;

	digitset = uppercase ? "0123456789ABCDEF" : "0123456789abcdef";
	sign = 0;
	prefixLen = 0;
	precisionGiven = precision >= 0;
	valueIsZero = (value == 0);
	ndigits = 0;
	precisionZeros = 0;

	/* Negative numbers always print out their '-'. Check flags and set appropriate sign. */
	if (negative)
		sign = '-';
	else if (flags & NSStringBuilderFlagPlus)
		sign = '+';
	else if (flags & NSStringBuilderFlagSpace)
		sign = ' ';

	/* Convert each digit to a character. Base is always 8, 10, or 16, so this should never read out of bounds. */
	while (value != 0) {
		digits[ndigits++] = digitset[value % base];
		value /= base;
	}

	/*
	 * The standard says converting a value of zero with an explicit precision of zero yields no characters at
	 * all. In every other case (no precision specified, or precision > 0), we want at least the literal '0' to
	 * appear, so put it into the digit buffer here.
	 */
	if (valueIsZero && !(precisionGiven && precision == 0))
		digits[ndigits++] = '0';

	/*
	 * The precision sub-specifier acts as a minimum digit count. If the natural conversion gave fewer digits,
	 * pad with leading zeros. We record the deficit but don't store the zeros in `digits`, since precision can be
	 * arbitrarily large. They'll be emitted right before the real digits during output assembly.
	 */
	if (precisionGiven && precision > ndigits)
		precisionZeros = precision - ndigits;

	/*
	 * For octals, force a leading '0', but only if the leading character isn't already a '0' from precision
	 * padding or the conversion itself. For hex, prepend 0{x,X} as a separate prefix.
	 */
	if (flags & NSStringBuilderFlagHash) {
		if (base == 8) {
			if (precisionZeros == 0 && (ndigits == 0 || digits[ndigits - 1] != '0'))
				digits[ndigits++] = '0';
		} else if (base == 16 && !valueIsZero) {
			prefix[0] = '0';
			prefix[1] = uppercase ? 'X' : 'x';
			prefixLen = 2;
		}
	}

	/* Count total number of number-related bytes including the sign, prefix, precision zeros, and digits. */
	total = (NSUInteger)(sign ? 1 : 0) + (NSUInteger)prefixLen + (NSUInteger)precisionZeros + (NSUInteger)ndigits;

	/* From that, calculate if we need any padding. */
	pad = (width > 0 && (NSUInteger)width > total) ? (NSUInteger)width - total : 0;

	/* The '-' flag and precision sub-specifier overrides the zero flag. */
	zeroPad = (flags & NSStringBuilderFlagZero) && !(flags & NSStringBuilderFlagMinus) && !precisionGiven;

	/* If padding was requested, add spaces if neither left-justification nor zero-padding was requested. */
	if (!(flags & NSStringBuilderFlagMinus) && !zeroPad)
		NSStringBuilderPad(buf, ' ', pad);

	/*
	 * Print '-' for negative numbers, and, if requested, '+' for positive numbers, or ' ' if no sign will be
	 * written.
	 */
	if (sign)
		NSStringBuilderAppendByte(buf, sign);

	/* Hex numbers have a 0{x,X} prefix. sign is always false in these cases. */
	if (prefixLen > 0)
		NSStringBuilderAppendBytes(buf, prefix, (NSUInteger)prefixLen);

	/* Pad with zeroes if requested. */
	if (zeroPad)
		NSStringBuilderPad(buf, '0', pad);

	/* Leading zeros from the precision sub-specifier, written directly here rather than into `digits`. */
	NSStringBuilderPad(buf, '0', (NSUInteger)precisionZeros);

	/* Read digits from higher place values first. */
	for (int i = ndigits - 1; i >= 0; --i)
		NSStringBuilderAppendByte(buf, digits[i]);

	/* '-' makes writespace padding appear on the right. */
	if (flags & NSStringBuilderFlagMinus)
		NSStringBuilderPad(buf, ' ', pad);
}

/*
 * Decimal-digit count of `n`. Returns 0 for n == 0 (so callers can distinguish the "value is zero" case from any
 * nonzero one-digit value). Schubfach significands are at most 17 digits, so the loop is bounded.
 */
[[clang::always_inline]]
static inline int
NSStringBuilderDigitCount(unsigned long n)
{
	int count = 0;

	while (n != 0) {
		n /= 10;
		++count;
	}

	return count;
}

/*
 * In-place rounding of an NSDecimalDouble to `n` retained significant digits, round-half-up. There are three cases:
 *
 *   - n >= digit_count(sig): nothing to do.
 *   - 0 < n < digit_count(sig): divide sig by 10^(drop), round the discarded remainder, and bump exp10 by drop.
 *     If `sig + 1` carries past 10^n (e.g.: 999 to 1000 with n = 3), one more division by 10 brings it back to
 *     n digits and exp10 bumps by another one (so 9.99 -> 10.0 stays a 3-digit answer).
 *   - n <= 0: the value rounds to either literal zero or to a single '1' at position exp10 + digit_count(sig).
 */
[[clang::always_inline]]
static inline void
NSStringBuilderRound(NSDecimalDouble *s, int n)
{
	int nd;
	int drop;
	unsigned long divisor;
	unsigned long remainder;

	if (s->kind != NSDoubleKindRegular || s->significand == 0)
		return;

	nd = NSStringBuilderDigitCount(s->significand);

	/* No need to do anything if requested precision is above digit count. */
	if (n >= nd)
		return;

	if (n <= 0) {
		unsigned long leadingPlace = 1;

		for (int i = 1; i < nd; ++i)
			leadingPlace *= 10;

		if (n == 0 && s->significand / leadingPlace >= 5) {
			s->significand = 1;
			s->exp10 += nd;
		} else {
			s->significand = 0;
			s->exp10 = 0;
		}

		return;
	}

	/* 0 < n < nd: chop off `drop` low digits and round the remainder. */
	drop = nd - n;

	divisor = 1;
	for (int i = 0; i < drop; ++i)
		divisor *= 10;

	remainder = s->significand % divisor;
	s->significand /= divisor;
	s->exp10 += drop;

	if (remainder >= divisor / 2) {
		s->significand += 1;

		/* Carry might have pushed sig past 10^n (e.g.: 999 to 1000). Bring it back. */
		unsigned long pow10n = 1;
		for (int i = 0; i < n; ++i)
			pow10n *= 10;

		if (s->significand >= pow10n) {
			s->significand /= 10;
			s->exp10 += 1;
		}
	}
}

/*
 * Convert an NSDecimalDouble into the NSStringBuilderDec digit-string form expected by the format-layout code. Peels
 * the decimal digits off `sig` (most-significant first via a reversed scratch buffer) and sets exp10 to the
 * scientific exponent of the leading digit (digits[0] sits in the 10^exp10 place). Zero/NaN/inf get the "0"
 * placeholder; format functions filter NaN/inf out before reaching here.
 */
[[clang::always_inline]]
static inline NSStringBuilderDec
NSStringBuilderShortestDec(NSDecimalDouble s)
{
	NSStringBuilderDec r;
	char tmp[20];
	int nd;

	if (s.kind != NSDoubleKindRegular || s.significand == 0) {
		r.digits[0] = '0';
		r.ndigits = 1;
		r.exp10 = 0;
		return r;
	}

	nd = 0;
	while (s.significand != 0) {
		tmp[nd++] = (char)('0' + s.significand % 10);
		s.significand /= 10;
	}

	for (int i = 0; i < nd; ++i)
		r.digits[i] = tmp[nd - 1 - i];

	r.ndigits = nd;
	r.exp10 = s.exp10 + nd - 1;

	return r;
}

/*
 * Write the "e+NN" / "E-NN" tail used by %e, %E, %g, %G into a caller-supplied character buffer, returning a pointer
 * to the byte after the last one written. At least two exponent digits and an explicit sign, so even an exponent of
 * zero comes out as "e+00".
 */
[[clang::always_inline]]
static inline char *
NSStringBuilderExpSuffix(char *p, int exp10, bool uppercase)
{
	int absExp;

	/* Letter that introduces the exponent: 'e' or 'E'. */
	*p++ = uppercase ? 'E' : 'e';

	/* Sign character is mandatory even for non-negative exponents. */
	if (exp10 < 0) {
		*p++ = '-';
		absExp = -exp10;
	} else {
		*p++ = '+';
		absExp = exp10;
	}

	/* Emit the high-order digits if the magnitude actually requires them, working from the largest place down. */
	if (absExp >= 1000) {
		*p++ = (char)('0' + absExp / 1000);
		absExp %= 1000;
		*p++ = (char)('0' + absExp / 100);
		absExp %= 100;
	} else if (absExp >= 100) {
		*p++ = (char)('0' + absExp / 100);
		absExp %= 100;
	}

	/* The final two digits are always written, even if both are zero, to satisfy the minimum-width rule. */
	*p++ = (char)('0' + absExp / 10);
	*p++ = (char)('0' + absExp % 10);

	return p;
}

[[clang::always_inline]]
static inline char
NSStringBuilderSignChar(bool negative, int flags)
{
	if (negative)
		return '-';
	if (flags & NSStringBuilderFlagPlus)
		return '+';
	if (flags & NSStringBuilderFlagSpace)
		return ' ';

	return 0;
}

[[clang::always_inline]]
static inline bool
NSStringBuilderHandleSpecial(NSStringBuilderBuffer *buf, double v, char conv, int flags, int width)
{
	char const *word;
	NSUInteger wordLen;
	char sign;
	bool uppercase;

	uppercase = (conv == 'F' || conv == 'E' || conv == 'G' || conv == 'A');

	if (__builtin_isnan(v)) {
		word = uppercase ? "NAN" : "nan";
		wordLen = 3;
	} else if (__builtin_isinf(v)) {
		word = uppercase ? "INF" : "inf";
		wordLen = 3;
	} else
		return false;

	/* Get sign character (if needed) and pad. */
	sign = NSStringBuilderSignChar(__builtin_signbit(v) != 0, flags);
	NSStringBuilderEmitPadded(buf, sign, nullptr, 0, word, wordLen, flags & ~NSStringBuilderFlagZero, width, false);

	return true;
}

/*
 * %f / %F. Get the shortest round-tripping (sig, exp10) from Schubfach, round at the precision boundary, then lay the
 * digits out with the decimal point in the right place. The body is staged in a byte buffer (so unbounded precision
 * can't overflow a fixed array) and handed to the generic padder; special values are handled up top.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderFormatF(NSStringBuilderBuffer *buf, double v, char conv, int flags, int width, int precision)
{
	double absV;
	bool negative;
	NSDecimalDouble s;
	NSStringBuilderDec r;
	NSStringBuilderBuffer body = { 0 };
	int nd;
	int leadingExp;
	int intDigits;
	char sign;
	bool zeroPad;

	/* NaN / inf get printed as words; nothing left to do here in that case. */
	if (NSStringBuilderHandleSpecial(buf, v, conv, flags, width))
		return;

	/* Capture the sign and work with the magnitude from here on. */
	negative = __builtin_signbit(v) != 0;
	absV = negative ? -v : v;

	/* Shortest round-tripping (sig, exp10) from Schubfach. */
	NSDoubleToDecimal(absV, &s);

	/* How many digits does the significand have? Literal zero has "zero" digits. */
	nd = NSStringBuilderDigitCount(s.significand);

	/*
	 * leadingExp is the base-10 column index of the most significant nonzero digit: written in scientific
	 * notation n.nnnn, it is the exponent of the leading digit.
	 */
	leadingExp = (nd == 0) ? 0 : s.exp10 + nd - 1;

	/*
	 * If no precision was given, fall back to the "shortest unique" representation: exactly enough fractional
	 * digits to round-trip the double, which is nd - leadingExp - 1 clamped at 0.
	 */
	if (precision < 0)
		precision = (nd > leadingExp + 1) ? nd - leadingExp - 1 : 0;

	/* Round at precision boundary (a no-op when precision came from the "shortest" branch above). */
	NSStringBuilderRound(&s, leadingExp + precision + 1);
	r = NSStringBuilderShortestDec(s);

	/*
	 * Integer part. For exp10 >= 0 we write exp10 + 1 digits; whatever Schubfach didn't supply (because the value
	 * exceeds what a double can represent) is filled with '0'. For exp10 < 0 the value is below 1, so the integer
	 * part is just a single '0' before the decimal point.
	 */
	if (r.exp10 >= 0) {
		intDigits = r.exp10 + 1;
		for (int i = 0; i < intDigits; ++i)
			NSStringBuilderAppendByte(&body, i < r.ndigits ? r.digits[i] : '0');
	} else
		NSStringBuilderAppendByte(&body, '0');

	/* Print decimal point if we write any fractional digits, or if the '#' flag requests it. */
	if (precision > 0 || (flags & NSStringBuilderFlagHash))
		NSStringBuilderAppendByte(&body, '.');

	/*
	 * Fractional digits. The unified index `j + r.exp10 + 1` covers both the exp10 >= 0 and exp10 < 0 cases;
	 * indices out of range get a '0' (leading or trailing zero padding).
	 */
	for (int j = 0; j < precision; ++j) {
		int idx = r.exp10 + 1 + j;

		NSStringBuilderAppendByte(&body, (idx < 0 || idx >= r.ndigits) ? '0' : r.digits[idx]);
	}

	/* Hand off to the generic padder. Zero-pad goes between sign and body when the '0' flag is set. */
	sign = NSStringBuilderSignChar(negative, flags);
	zeroPad = (flags & NSStringBuilderFlagZero) && !(flags & NSStringBuilderFlagMinus);
	NSStringBuilderEmitPadded(buf, sign, nullptr, 0, (char const *)body.data, body.length, flags, width, zeroPad);

	free(body.data);
}

[[clang::always_inline]]
static inline void
NSStringBuilderFormatE(NSStringBuilderBuffer *buf, double v, char conv, int flags, int width, int precision)
{
	bool negative;
	double absV;
	NSDecimalDouble s;
	NSStringBuilderDec r;
	bool uppercase;
	NSStringBuilderBuffer body = { 0 };
	char expBuf[6];
	char *expEnd;
	char sign;
	bool zeroPad;

	/* NaN / inf get printed as words; nothing left to do here in that case. */
	if (NSStringBuilderHandleSpecial(buf, v, conv, flags, width))
		return;

	uppercase = (conv == 'E');
	negative = __builtin_signbit(v) != 0;
	absV = negative ? -v : v;

	/* Shortest round-tripping (sig, exp10) from Schubfach. */
	NSDoubleToDecimal(absV, &s);

	/*
	 * If no precision was given, fall back to the "shortest unique" representation. With %e the leading digit is
	 * always present, so we need (digit_count - 1) trailing digits to round-trip.
	 */
	if (precision < 0) {
		int nd_e = NSStringBuilderDigitCount(s.significand);

		precision = nd_e > 1 ? nd_e - 1 : 0;
	}

	/* Round at precision boundary (no-op when precision was derived from "shortest" above). */
	NSStringBuilderRound(&s, precision + 1);
	r = NSStringBuilderShortestDec(s);

	/* Print leading digit if it exists. */
	NSStringBuilderAppendByte(&body, r.ndigits > 0 ? r.digits[0] : '0');

	/* Print decimal point if we write any fractional digits, or if the '#' flag requests it. */
	if (precision > 0 || (flags & NSStringBuilderFlagHash))
		NSStringBuilderAppendByte(&body, '.');

	/* For all representable digits in the significand, print them out. */
	for (int j = 0; j < precision; ++j)
		NSStringBuilderAppendByte(&body, j + 1 < r.ndigits ? r.digits[j + 1] : '0');

	/* Get the exponent tail. */
	expEnd = NSStringBuilderExpSuffix(expBuf, absV == 0.0 ? 0 : r.exp10, uppercase);
	NSStringBuilderAppendBytes(&body, expBuf, (NSUInteger)(expEnd - expBuf));

	/* Get sign if requested, pad with zeroes if requested (and not overridden by '0' flag), and pad. */
	sign = NSStringBuilderSignChar(negative, flags);
	zeroPad = (flags & NSStringBuilderFlagZero) && !(flags & NSStringBuilderFlagMinus);
	NSStringBuilderEmitPadded(buf, sign, nullptr, 0, (char const *)body.data, body.length, flags, width, zeroPad);

	free(body.data);
}

[[clang::always_inline]]
static inline void
NSStringBuilderFormatG(NSStringBuilderBuffer *buf, double v, char conv, int flags, int width, int precision)
{
	bool negative;
	double absV;
	int sig;
	NSDecimalDouble s;
	NSStringBuilderDec r;
	bool uppercase;
	bool useE;
	NSStringBuilderBuffer body = { 0 };
	NSUInteger trailZeros;
	char sign;
	bool zeroPad;

	if (NSStringBuilderHandleSpecial(buf, v, conv, flags, width))
		return;

	uppercase = (conv == 'G');
	negative = __builtin_signbit(v) != 0;
	absV = negative ? -v : v;

	/* Shortest round-tripping (sig, exp10) from Schubfach. */
	NSDoubleToDecimal(absV, &s);

	/*
	 * If no precision was given, fall back to "shortest unique": use Schubfach's significant-digit count as the %g
	 * precision so we round-trip the double exactly. If precision was explicitly given, the C rule "precision 0 is
	 * treated as 1" still applies.
	 */
	if (precision < 0) {
		int nd_g = NSStringBuilderDigitCount(s.significand);

		sig = nd_g > 0 ? nd_g : 1;
	} else {
		sig = precision;
		if (sig == 0)
			sig = 1;
	}

	NSStringBuilderRound(&s, sig);
	r = NSStringBuilderShortestDec(s);

	if (absV == 0.0)
		useE = false;
	else if (r.exp10 < -4 || r.exp10 >= sig)
		useE = true;
	else
		useE = false;

	if (useE) {
		int eprec = sig - 1;
		char expBuf[16];
		char *expEnd;

		NSStringBuilderAppendByte(&body, r.ndigits > 0 ? r.digits[0] : '0');

		trailZeros = 0;
		if (eprec > 0 || (flags & NSStringBuilderFlagHash))
			NSStringBuilderAppendByte(&body, '.');

		for (int j = 0; j < eprec; ++j) {
			char d = j + 1 < r.ndigits ? r.digits[j + 1] : '0';

			NSStringBuilderAppendByte(&body, d);

			if (d == '0')
				++trailZeros;
			else
				trailZeros = 0;
		}

		if (!(flags & NSStringBuilderFlagHash)) {
			body.length -= trailZeros;
			if (body.length > 0 && ((char *)body.data)[body.length - 1] == '.')
				--body.length;
		}

		expEnd = NSStringBuilderExpSuffix(expBuf, r.exp10, uppercase);
		NSStringBuilderAppendBytes(&body, expBuf, (NSUInteger)(expEnd - expBuf));
	} else {
		int fprec;
		int intDigits;

		fprec = sig - 1 - r.exp10;
		if (fprec < 0)
			fprec = 0;

		if (r.exp10 >= 0) {
			intDigits = r.exp10 + 1;
			for (int i = 0; i < intDigits; ++i)
				NSStringBuilderAppendByte(&body, i < r.ndigits ? r.digits[i] : '0');
		} else
			NSStringBuilderAppendByte(&body, '0');

		if (fprec > 0 || (flags & NSStringBuilderFlagHash))
			NSStringBuilderAppendByte(&body, '.');

		trailZeros = 0;
		for (int j = 0; j < fprec; ++j) {
			int idx;
			char d;

			if (r.exp10 >= 0)
				idx = r.exp10 + 1 + j;
			else
				idx = j + r.exp10 + 1;

			d = (idx < 0 || idx >= r.ndigits) ? '0' : r.digits[idx];

			NSStringBuilderAppendByte(&body, d);

			if (d == '0')
				++trailZeros;
			else
				trailZeros = 0;
		}

		if (!(flags & NSStringBuilderFlagHash)) {
			body.length -= trailZeros;
			if (body.length > 0 && ((char *)body.data)[body.length - 1] == '.')
				--body.length;
		}
	}

	sign = NSStringBuilderSignChar(negative, flags);
	zeroPad = (flags & NSStringBuilderFlagZero) && !(flags & NSStringBuilderFlagMinus);
	NSStringBuilderEmitPadded(buf, sign, nullptr, 0, (char const *)body.data, body.length, flags, width, zeroPad);

	free(body.data);
}

/*
 * %a / %A. Convert a double's IEEE 754 representation to a hexadecimal floating-point literal "0x1.MMMMp+EE".
 * Subnormals: leading digit is 0 and the exponent is fixed at -1022. Zero: "0x0p+0".
 */
[[clang::always_inline]]
static inline void
NSStringBuilderFormatA(NSStringBuilderBuffer *buf, double v, char conv, int flags, int width, int precision)
{
	bool negative;
	bool uppercase;
	unsigned long long bits;
	unsigned long long mantissa;
	int bexp;
	int unbiasedExp;
	int leadingDigit;
	NSStringBuilderBuffer body = { 0 };
	char fracHex[13];
	char prefix[2];
	char sign;
	bool zeroPad;
	bool precisionGiven;
	char const *hexset;

	if (NSStringBuilderHandleSpecial(buf, v, conv, flags, width))
		return;

	uppercase = (conv == 'A');
	hexset = uppercase ? "0123456789ABCDEF" : "0123456789abcdef";

	negative = __builtin_signbit(v) != 0;
	__builtin_memcpy(&bits, &v, sizeof bits);

	bexp = (int)((bits >> 52) & 0x7FFU);
	mantissa = bits & 0x000FFFFFFFFFFFFFULL;

	precisionGiven = precision >= 0;

	if (bexp == 0 && mantissa == 0) {
		leadingDigit = 0;
		unbiasedExp = 0;
	} else if (bexp == 0) {
		leadingDigit = 0;
		unbiasedExp = -1022;
	} else {
		leadingDigit = 1;
		unbiasedExp = bexp - 1023;
	}

	for (int i = 12; i >= 0; --i) {
		fracHex[i] = hexset[mantissa & 0xFU];
		mantissa >>= 4;
	}

	NSStringBuilderAppendByte(&body, (char)('0' + leadingDigit));

	if (precisionGiven) {
		int p = precision;

		if (p >= 13) {
			NSStringBuilderAppendByte(&body, '.');
			NSStringBuilderAppendBytes(&body, fracHex, 13);
			for (int i = 13; i < p; ++i)
				NSStringBuilderAppendByte(&body, '0');
		} else {
			char trunc[13];
			bool carry;
			char round;
			int rval;

			for (int i = 0; i < 13; ++i)
				trunc[i] = fracHex[i];

			round = trunc[p];
			rval = round >= 'a' ? round - 'a' + 10
			     : round >= 'A' ? round - 'A' + 10
			     : round - '0';
			carry = (rval >= 8);

			if (carry) {
				int i = p - 1;

				while (i >= 0 && carry) {
					int dval = trunc[i] >= 'a' ? trunc[i] - 'a' + 10
						 : trunc[i] >= 'A' ? trunc[i] - 'A' + 10
						 : trunc[i] - '0';

					if (dval < 15) {
						trunc[i] = hexset[dval + 1];
						carry = false;
					} else {
						trunc[i] = '0';
						--i;
					}
				}

				if (carry) {
					if (leadingDigit < 1)
						((char *)body.data)[0] = (char)('1');
					else
						++unbiasedExp;
				}
			}

			if (p > 0) {
				NSStringBuilderAppendByte(&body, '.');
				NSStringBuilderAppendBytes(&body, trunc, (NSUInteger)p);
			} else if (flags & NSStringBuilderFlagHash) {
				NSStringBuilderAppendByte(&body, '.');
			}
		}
	} else {
		int last = 13;

		while (last > 0 && fracHex[last - 1] == '0')
			--last;

		if (last > 0 || (flags & NSStringBuilderFlagHash))
			NSStringBuilderAppendByte(&body, '.');

		NSStringBuilderAppendBytes(&body, fracHex, (NSUInteger)last);
	}

	NSStringBuilderAppendByte(&body, uppercase ? 'P' : 'p');

	if (unbiasedExp < 0) {
		NSStringBuilderAppendByte(&body, '-');
		unbiasedExp = -unbiasedExp;
	} else {
		NSStringBuilderAppendByte(&body, '+');
	}

	{
		char tmp[8];
		int n = 0;

		if (unbiasedExp == 0) {
			tmp[n++] = '0';
		} else {
			while (unbiasedExp != 0) {
				tmp[n++] = (char)('0' + unbiasedExp % 10);
				unbiasedExp /= 10;
			}
		}

		for (int i = n - 1; i >= 0; --i)
			NSStringBuilderAppendByte(&body, tmp[i]);
	}

	prefix[0] = '0';
	prefix[1] = uppercase ? 'X' : 'x';

	sign = NSStringBuilderSignChar(negative, flags);
	zeroPad = (flags & NSStringBuilderFlagZero) && !(flags & NSStringBuilderFlagMinus);
	NSStringBuilderEmitPadded(buf, sign, prefix, 2, (char const *)body.data, body.length, flags, width, zeroPad);

	free(body.data);
}

/* Parse a decimal integer starting at *ip. Updates *ip to point past it. Returns 0 if no digit is found. */
[[clang::always_inline]]
static inline int
NSStringBuilderParseInt(NSString *fmt, NSUInteger *ip, NSUInteger len)
{
	int n;
	unichar c;

	n = 0;

	while (*ip < len) {
		c = [fmt characterAtIndex:*ip];

		if (c < '0' || c > '9')
			break;

		if (n > (INT_MAX - 9) / 10) {
			++*ip;
			continue;
		}

		n = n * 10 + (int)(c - '0');
		++*ip;
	}

	return n;
}

/* %d / %i / %u / %o / %x / %X. Reads the argument per length modifier and signedness, then defers to FormatInt. */
[[clang::always_inline]]
static inline void
NSStringBuilderEmitInteger(NSStringBuilderBuffer *buf, __builtin_va_list *apPtr, unichar conv, int flags, int width,
		int precision, int lenMod)
{
	if (conv == 'd' || conv == 'i') {
		long long sv;
		bool negative;
		unsigned long long uv;

		switch (lenMod) {
		case NSStringBuilderLenChar:
			sv = (signed char)__builtin_va_arg(*apPtr, int);
			break;
		case NSStringBuilderLenShort:
			sv = (short)__builtin_va_arg(*apPtr, int);
			break;
		case NSStringBuilderLenLong:
			sv = __builtin_va_arg(*apPtr, long);
			break;
		case NSStringBuilderLenLongLong:
			sv = __builtin_va_arg(*apPtr, long long);
			break;
		case NSStringBuilderLenIntMax:
			sv = __builtin_va_arg(*apPtr, long long);
			break;
		case NSStringBuilderLenSize:
			sv = (long long)__builtin_va_arg(*apPtr, long);
			break;
		case NSStringBuilderLenPtrDiff:
			sv = (long long)__builtin_va_arg(*apPtr, long);
			break;
		default:
			sv = __builtin_va_arg(*apPtr, int);
			break;
		}

		/* TODO: abs of LONG_MIN is unrepresentable. */
		negative = sv < 0;
		uv = negative ? (unsigned long long)(-(sv + 1)) + 1U : (unsigned long long)sv;

		NSStringBuilderFormatInt(buf, uv, negative, 10, false, flags, width, precision);
	} else {
		unsigned long long uv;
		unsigned int base;
		bool upper;

		switch (lenMod) {
		case NSStringBuilderLenChar:
			uv = (unsigned char)__builtin_va_arg(*apPtr, unsigned int);
			break;
		case NSStringBuilderLenShort:
			uv = (unsigned short)__builtin_va_arg(*apPtr, unsigned int);
			break;
		case NSStringBuilderLenLong:
			uv = __builtin_va_arg(*apPtr, unsigned long);
			break;
		case NSStringBuilderLenLongLong:
			uv = __builtin_va_arg(*apPtr, unsigned long long);
			break;
		case NSStringBuilderLenIntMax:
			uv = __builtin_va_arg(*apPtr, unsigned long long);
			break;
		case NSStringBuilderLenSize:
			uv = __builtin_va_arg(*apPtr, unsigned long);
			break;
		case NSStringBuilderLenPtrDiff:
			uv = (unsigned long long)__builtin_va_arg(*apPtr, long);
			break;
		default:
			uv = __builtin_va_arg(*apPtr, unsigned int);
			break;
		}

		/* Are we an unsigned decimal integer (base 10), an octal (base 8), or hex (base 16)? */
		base = (conv == 'u') ? 10 : (conv == 'o') ? 8 : 16;
		upper = (conv == 'X');

		NSStringBuilderFormatInt(buf, uv, false, base, upper, flags, width, precision);
	}
}

/* %f / %F / %e / %E / %g / %G / %a / %A. Reads the double (honoring the 'L' modifier) and dispatches by conversion. */
[[clang::always_inline]]
static inline void
NSStringBuilderEmitFloat(NSStringBuilderBuffer *buf, __builtin_va_list *apPtr, unichar conv, int flags, int width,
		int precision, int lenMod)
{
	double dv;

	if (lenMod == NSStringBuilderLenLongDouble)
		dv = (double)__builtin_va_arg(*apPtr, long double);
	else
		dv = __builtin_va_arg(*apPtr, double);

	switch (conv) {
	case 'f':
	case 'F':
		NSStringBuilderFormatF(buf, dv, (char)conv, flags, width, precision);
		break;
	case 'e':
	case 'E':
		NSStringBuilderFormatE(buf, dv, (char)conv, flags, width, precision);
		break;
	case 'g':
	case 'G':
		NSStringBuilderFormatG(buf, dv, (char)conv, flags, width, precision);
		break;
	case 'a':
	case 'A':
		NSStringBuilderFormatA(buf, dv, (char)conv, flags, width, precision);
		break;
	}
}

/* %c. A single byte, widened to the output encoding, with width padding. */
[[clang::always_inline]]
static inline void
NSStringBuilderEmitChar(NSStringBuilderBuffer *buf, __builtin_va_list *apPtr, int flags, int width)
{
	unsigned char ch = (unsigned char)__builtin_va_arg(*apPtr, int);
	char body[1] = { (char)ch };

	NSStringBuilderEmitPadded(buf, 0, nullptr, 0, body, 1, flags, width, false);
}

/* %C. A UTF-16 code unit; a lone surrogate becomes U+FFFD. Width counts code points, so it pads by width - 1. */
[[clang::always_inline]]
static inline void
NSStringBuilderEmitUnichar(NSStringBuilderBuffer *buf, __builtin_va_list *apPtr, int flags, int width)
{
	unichar uc = (unichar)__builtin_va_arg(*apPtr, int);
	unsigned int cp;
	NSUInteger pad;

	/* Surrogates cannot be represented standalone; emit a replacement character in that case. */
	cp = (uc >= 0xD800 && uc <= 0xDFFF) ? 0xFFFD : uc;

	pad = (width > 0 && (NSUInteger)width > 1) ? (NSUInteger)width - 1 : 0;

	if (!(flags & NSStringBuilderFlagMinus))
		NSStringBuilderPad(buf, ' ', pad);

	NSStringBuilderAppendCodePoint(buf, cp);

	if (flags & NSStringBuilderFlagMinus)
		NSStringBuilderPad(buf, ' ', pad);
}

/* %s. A C string capped by precision, emitted as external bytes through the generic padder. */
[[clang::always_inline]]
static inline void
NSStringBuilderEmitCString(NSStringBuilderBuffer *buf, __builtin_va_list *apPtr, int flags, int width, int precision)
{
	char const *s = __builtin_va_arg(*apPtr, char const *);
	NSUInteger slen = 0;

	if (s == nullptr)
		s = "(null)";

	/* Precision puts a cap on how many characters we print. */
	if (precision >= 0) {
		while (slen < (NSUInteger)precision && s[slen] != '\0')
			++slen;
	} else {
		while (s[slen] != '\0')
			++slen;
	}

	NSStringBuilderEmitPadded(buf, 0, nullptr, 0, s, slen, flags, width, false);
}

/*
 * %S. A UTF-16 string capped by precision. Surrogate pairs are combined; width counts code points, not code units,
 * so it cannot use the byte-oriented padder. The content is staged into a scratch buffer in the output encoding
 * (so the code-point count is finalized before any padding is emitted), then copied through.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderEmitUnicharString(NSStringBuilderBuffer *buf, __builtin_va_list *apPtr, int flags, int width,
		int precision)
{
	unichar const *s = __builtin_va_arg(*apPtr, unichar const *);
	NSStringBuilderBuffer tmp = { 0 };
	NSUInteger pad;
	NSUInteger written;

	tmp.encoding = buf->encoding;
	tmp.isASCII = true;

	if (s == nullptr) {
		NSStringBuilderAppendBytes(&tmp, "(null)", 6);
		written = 6;
	} else {
		NSUInteger n = 0;

		/* Precision puts a cap on how many code units we print. */
		if (precision >= 0) {
			while (n < (NSUInteger)precision && s[n] != 0)
				++n;
		} else {
			while (s[n] != 0)
				++n;
		}

		written = n;

		/* Loop through the code units; handle surrogate pairs. */
		for (NSUInteger k = 0; k < n; ++k) {
			unichar uc = s[k];

			if (uc >= 0xD800 && uc <= 0xDBFF) {
				if (k + 1 >= n) {
					NSStringBuilderAppendCodePoint(&tmp, 0xFFFD);
					break;
				}

				unichar uc2 = s[k + 1];

				if (uc2 >= 0xDC00 && uc2 <= 0xDFFF) {
					unsigned int cp = 0x10000U + (((unsigned int)uc - 0xD800U) << 10) +
							((unsigned int)uc2 - 0xDC00U);

					NSStringBuilderAppendCodePoint(&tmp, cp);
					++k;
					--written;
					continue;
				} else {
					NSStringBuilderAppendCodePoint(&tmp, 0xFFFD);
					continue;
				}
			}

			if (uc >= 0xDC00 && uc <= 0xDFFF)
				NSStringBuilderAppendCodePoint(&tmp, 0xFFFD);
			else
				NSStringBuilderAppendCodePoint(&tmp, uc);
		}
	}

	/* We pad by code points for width, not by elements, hence we do not call NSStringBuilderEmitPadded() here. */
	pad = (width > 0 && (NSUInteger)width > written) ? (NSUInteger)width - written : 0;

	if (!(flags & NSStringBuilderFlagMinus))
		NSStringBuilderPad(buf, ' ', pad);

	NSStringBuilderAppendRun(buf, &tmp);

	if (flags & NSStringBuilderFlagMinus)
		NSStringBuilderPad(buf, ' ', pad);

	free(tmp.data);
}

/* %p. The pointer in hex with a "0x" prefix. */
[[clang::always_inline]]
static inline void
NSStringBuilderEmitPointer(NSStringBuilderBuffer *buf, __builtin_va_list *apPtr, int flags, int width)
{
	void *pv = __builtin_va_arg(*apPtr, void *);
	char prefix[2] = { '0', 'x' };
	char body[18];
	NSUInteger bodyLen = 0;
	uintptr_t uv = (uintptr_t)pv;
	char digits[16];
	int ndigits = 0;
	bool zeroPad;

	while (uv != 0) {
		digits[ndigits++] = "0123456789abcdef"[uv & 0xFU]; /* I love C. */
		uv >>= 4;
	}

	if (ndigits == 0)
		digits[ndigits++] = '0';

	for (int k = ndigits - 1; k >= 0; --k)
		body[bodyLen++] = digits[k];

	zeroPad = (flags & NSStringBuilderFlagZero) && !(flags & NSStringBuilderFlagMinus);
	NSStringBuilderEmitPadded(buf, 0, prefix, 2, body, bodyLen, flags, width, zeroPad);
}

/* %@. The object's -description, padded by width measured in UTF-16 code units (matching the description's length). */
[[clang::always_inline]]
static inline void
NSStringBuilderEmitObject(NSStringBuilderBuffer *buf, __builtin_va_list *apPtr, int flags, int width)
{
	id obj = __builtin_va_arg(*apPtr, id);
	NSString *desc;
	NSUInteger objLen;
	NSUInteger pad;

	if (obj == nil) {
		NSStringBuilderEmitPadded(buf, 0, nullptr, 0, "(nil)", 5, flags, width, false);
		return;
	}

	desc = [(id<NSObject>)obj description];
	objLen = desc.length;

	pad = (width > 0 && (NSUInteger)width > objLen) ? (NSUInteger)width - objLen : 0;

	if (!(flags & NSStringBuilderFlagMinus))
		NSStringBuilderPad(buf, ' ', pad);

	NSStringBuilderAppendString(buf, desc);

	if (flags & NSStringBuilderFlagMinus)
		NSStringBuilderPad(buf, ' ', pad);
}

/*
 * Process one '%...' specifier, starting at index *ip (which points at the '%'). On return, *ip points past the
 * consumed specifier. Emits the result into buf.
 */
[[clang::always_inline]]
static inline void
NSStringBuilderProcessSpec(NSStringBuilderBuffer *buf, NSString *fmt, NSUInteger *ip, NSUInteger len,
		__builtin_va_list *apPtr)
{
	NSUInteger startIdx;
	NSUInteger i;
	unichar c;
	int flags;
	int width;
	int precision;
	int lenMod;

	startIdx = *ip;
	i = startIdx + 1;
	flags = 0;
	width = 0;
	precision = -1;
	lenMod = NSStringBuilderLenNone;

	/* Parse flags sub-specifier. */
	for (; i < len; ++i) {
		c = [fmt characterAtIndex:i];

		switch (c) {
		case '-':
			flags |= NSStringBuilderFlagMinus;
			continue;
		case '+':
			flags |= NSStringBuilderFlagPlus;
			continue;
		case ' ':
			flags |= NSStringBuilderFlagSpace;
			continue;
		case '#':
			flags |= NSStringBuilderFlagHash;
			continue;
		case '0':
			flags |= NSStringBuilderFlagZero;
			continue;
		default:
			break;
		}

		break;
	}

	/* Parse width sub-specifier. */
	if (i < len && [fmt characterAtIndex:i] == '*') {
		int w = __builtin_va_arg(*apPtr, int);

		/* TODO: handle INT_MIN! */
		if (w < 0) {
			flags |= NSStringBuilderFlagMinus;
			w = -w;
		}

		width = w;
		++i;
	} else {
		width = NSStringBuilderParseInt(fmt, &i, len);
	}

	/* Parse precision sub-specifier. */
	if (i < len && [fmt characterAtIndex:i] == '.') {
		++i;
		if (i < len && [fmt characterAtIndex:i] == '*') {
			precision = __builtin_va_arg(*apPtr, int);
			if (precision < 0)
				precision = -1;
			++i;
		} else {
			precision = NSStringBuilderParseInt(fmt, &i, len);
		}
	}

	/* Parse length sub-specifier. */
	if (i < len) {
		c = [fmt characterAtIndex:i];

		switch (c) {
		case 'h':
			++i;
			if (i < len && [fmt characterAtIndex:i] == 'h') {
				lenMod = NSStringBuilderLenChar;
				++i;
			} else {
				lenMod = NSStringBuilderLenShort;
			}
			break;
		case 'l':
			++i;
			if (i < len && [fmt characterAtIndex:i] == 'l') {
				lenMod = NSStringBuilderLenLongLong;
				++i;
			} else {
				lenMod = NSStringBuilderLenLong;
			}
			break;
		case 'j':
			lenMod = NSStringBuilderLenIntMax;
			++i;
			break;
		case 'z':
			lenMod = NSStringBuilderLenSize;
			++i;
			break;
		case 't':
			lenMod = NSStringBuilderLenPtrDiff;
			++i;
			break;
		case 'L':
			lenMod = NSStringBuilderLenLongDouble;
			++i;
			break;
		default:
			break;
		}
	}

	/* Bail out if the format specifier is invalid. */
	if (i >= len) {
		NSStringBuilderAppendByte(buf, '%');
		*ip = i;
		return;
	}

	/* Get specifier and parse argument. */
	c = [fmt characterAtIndex:i];

	switch (c) {
	case '%':
		NSStringBuilderAppendByte(buf, '%');
		*ip = i + 1;
		return;

	case 'd':
	case 'i':
	case 'u':
	case 'o':
	case 'x':
	case 'X':
		NSStringBuilderEmitInteger(buf, apPtr, c, flags, width, precision, lenMod);
		break;

	case 'f':
	case 'F':
	case 'e':
	case 'E':
	case 'g':
	case 'G':
	case 'a':
	case 'A':
		NSStringBuilderEmitFloat(buf, apPtr, c, flags, width, precision, lenMod);
		break;

	case 'c':
		NSStringBuilderEmitChar(buf, apPtr, flags, width);
		break;

	case 'C':
		NSStringBuilderEmitUnichar(buf, apPtr, flags, width);
		break;

	case 's':
		NSStringBuilderEmitCString(buf, apPtr, flags, width, precision);
		break;

	case 'S':
		NSStringBuilderEmitUnicharString(buf, apPtr, flags, width, precision);
		break;

	case 'p':
		NSStringBuilderEmitPointer(buf, apPtr, flags, width);
		break;

	case '@':
		NSStringBuilderEmitObject(buf, apPtr, flags, width);
		break;

	default:
		NSStringBuilderAppendByte(buf, '%');
		*ip = startIdx + 1;
		return;
	}

	*ip = i + 1;
}

/*
 * Build `format` with `arguments` into a freshly malloc'd buffer in the requested encoding and return it. The caller
 * owns result.data. `format` must not be nil (callers validate, since their nil behavior differs).
 */
NSStringBuilderResult
NSStringBuilder(NSStringBuilderEncoding encoding, NSString *format, __builtin_va_list arguments)
{
	NSStringBuilderBuffer buf = { 0 };
	__builtin_va_list ap;
	NSUInteger len;
	NSUInteger i;
	unichar c;
	NSStringBuilderResult result;

	buf.encoding = encoding;
	buf.isASCII = true;

	__builtin_va_copy(ap, arguments);

	len = format.length;
	i = 0;

	while (i < len) {
		c = [format characterAtIndex:i];

		if (c == '%')
			NSStringBuilderProcessSpec(&buf, format, &i, len, &ap);
		else
			NSStringBuilderAppendUnichar(&buf, format, &i, len);
	}

	__builtin_va_end(ap);

	result.encoding = encoding;
	result.length = buf.length;
	result.isASCII = buf.isASCII;

	if (encoding == NSStringBuilderEncodingUTF8)
		result.data.utf8 = (char *)buf.data;
	else
		result.data.utf16 = (unichar *)buf.data;

	return result;
}

#pragma clang diagnostic pop

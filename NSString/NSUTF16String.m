
#import <FoundationPrivate/NSString/NSString.h>

@interface NSUTF16String ()

@property (nonatomic, readonly, direct) bool freeWhenDone;
@property (nonatomic, readonly, direct) void *stringMemory;
@property (nonatomic, readonly, direct) unichar *string;

@end

@implementation NSUTF16String

@synthesize length = _length;
@synthesize freeWhenDone = _freeWhenDone;
@synthesize stringMemory = _stringMemory;
@synthesize string = _string;

/* Copy `units` 16-bit code units out of `src`, byte-swapping when the source order differs from the host. */
[[clang::always_inline]]
static inline void
DecodeUTF16(unichar *dst, char const *src, NSUInteger units, bool mustSwap)
{
	for (NSUInteger i = 0; i < units; ++i) {
		unichar unit;

		__builtin_memcpy_inline(&unit, src + i * sizeof(unichar), sizeof(unichar));
		dst[i] = mustSwap ? NSByteOrderSwapUnsignedShort(unit) : unit;
	}
}

/*
 * Resolve the byte order to decode with, and how many bytes a leading BOM consumes. Precondition: at least two bytes
 * are readable at bytes.
 *
 * Only NSUTF16StringEncoding inspects a byte-order mark; on a match the mark is stripped (it does not appear in the
 * resulting string) and chooses the order, otherwise big-endian is assumed. The explicit big- and little-endian
 * encodings never strip; a leading FE FF / FF FE is just another code unit and is kept, decoding to U+FEFF when it
 * matches the declared order or U+FFFE when it is the opposite.
 */
[[clang::always_inline]]
static inline NSByteOrder
ByteOrderForEncoding(NSStringEncoding encoding, char const *bytes, NSUInteger *offset)
{
	if (encoding == NSUTF16StringEncoding) {
		if ((unsigned char)bytes[0] == 0xFE && (unsigned char)bytes[1] == 0xFF) {
			*offset = sizeof(unichar);
			return NSByteOrderBigEndian;
		}

		if ((unsigned char)bytes[0] == 0xFF && (unsigned char)bytes[1] == 0xFE) {
			*offset = sizeof(unichar);
			return NSByteOrderLittleEndian;
		}

		*offset = 0;
		return NSByteOrderBigEndian;
	}

	*offset = 0;
	return encoding == NSUTF16BigEndianStringEncoding ? NSByteOrderBigEndian : NSByteOrderLittleEndian;
}

- (nullable instancetype)_initWithBytes:(char const *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding OBJC_DIRECT
{
	NSByteOrder order;
	NSUInteger offset;
	NSUInteger units;

	/* A lone trailing byte cannot form a code unit. */
	if (length == 1)
		return nil;

	/* Floor resulting unit count so trailing bytes are stripped away. */
	order = ByteOrderForEncoding(encoding, bytes, &offset);
	units = (length - offset) / sizeof(unichar);

	/*
	 * Reachable only for NSUTF16StringEncoding given a lone BOM (e.g.: "FE FF"): the mark is stripped and nothing
	 * remains.
	 */
	if (units == 0)
		return (id)@"";

	_length = units;
	_string = _NSMalloc(units * sizeof(unichar));
	DecodeUTF16(_string, bytes + offset, units, order != NSByteOrderHost());
	_stringMemory = _string;
	_freeWhenDone = true;

	return self;
}

- (nullable instancetype)_initWithBytesNoCopy:(char *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding freeWhenDone:(bool)freeBuffer OBJC_DIRECT
{
	NSByteOrder order;
	NSUInteger offset;
	NSUInteger units;

	if (length == 1) {
		if (freeBuffer)
			free(bytes);

		return nil;
	}

	order = ByteOrderForEncoding(encoding, bytes, &offset);
	units = (length - offset) / sizeof(unichar);

	if (units == 0) {
		if (freeBuffer)
			free(bytes);

		return (id)@"";
	}

	/*
	 * The buffer can be adopted in place only when no per-unit work is needed: the declared order already matches
	 * the host, and  the (BOM-adjusted) start is aligned for unichar access. Stripping a BOM shifts the start by
	 * one unit, which preserves alignment parity.
	 */
	if (order == NSByteOrderHost() && ((uintptr_t)bytes & (sizeof(unichar) - 1)) == 0) {
		_stringMemory = bytes;
		_string = (unichar *)(void *)(bytes + offset);
		_freeWhenDone = freeBuffer;
	} else {
		_string = _NSMalloc(units * sizeof(unichar));
		DecodeUTF16(_string, bytes + offset, units, order != NSByteOrderHost());
		_stringMemory = _string;
		_freeWhenDone = true;

		if (freeBuffer)
			free(bytes);
	}

	_length = units;

	return self;
}

- (instancetype)_initWithCharacters:(unichar const *)characters length:(NSUInteger)length OBJC_DIRECT
{
	NSUInteger byteLength;

	/* unichars are assumed host-order code units. They are stored verbatim with no BOM or endianness parsing. */
	if (__builtin_mul_overflow(length, sizeof(unichar), &byteLength))
		abort();

	_length = length;
	_string = _NSMalloc(byteLength);
	memcpy(_string, characters, byteLength);
	_stringMemory = _string;
	_freeWhenDone = true;

	return self;
}

- (instancetype)_initWithCharactersNoCopy:(unichar *)characters length:(NSUInteger)length
		freeWhenDone:(bool)freeBuffer OBJC_DIRECT
{
	_length = length;
	_string = characters;
	_stringMemory = characters;
	_freeWhenDone = freeBuffer;

	return self;
}

- (unichar)characterAtIndex:(NSUInteger)index
{
	if (index >= _length)
		_NSRaiseException(MethodContext, NSRangeException, @"index out of bounds.");

	return _string[index];
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)range
{
	NSUInteger byteLength;

	if (_length == 0 || range.length == 0)
		return;

	if (buffer == nullptr || NSRangeMax(range) > _length)
		abort();

	if (__builtin_mul_overflow(range.length, sizeof(unichar), &byteLength))
		abort();

	memcpy(buffer, _string + range.location, byteLength);
}

- (void)dealloc
{
	if (_freeWhenDone)
		free(_stringMemory);
}

@end

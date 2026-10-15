
#import <FoundationPrivate/NSString/NSString.h>
#import <FoundationPrivate/NSString/NSStringBuilder.h>

/* Reject malformed, overlong, surrogate, and out-of-range UTF-8 sequences. */
static bool
UTF8IsValid(void const *bytes, NSUInteger length)
{
	unsigned char const *p = bytes;
	NSUInteger i = 0;

	while (i < length) {
		unsigned char lead = p[i++];

		if (lead <= 0x7F)
			continue;

		if (lead >= 0xC2 && lead <= 0xDF) {
			if (length - i < 1 || (p[i] & 0xC0) != 0x80)
				return false;

			i += 1;
			continue;
		}

		if (lead >= 0xE0 && lead <= 0xEF) {
			unsigned char second;

			if (length - i < 2)
				return false;

			second = p[i];
			if ((second & 0xC0) != 0x80 || (p[i + 1] & 0xC0) != 0x80)
				return false;
			if (lead == 0xE0 && second < 0xA0)
				return false;
			if (lead == 0xED && second >= 0xA0)
				return false;

			i += 2;
			continue;
		}

		if (lead >= 0xF0 && lead <= 0xF4) {
			unsigned char second;

			if (length - i < 3)
				return false;

			second = p[i];
			if ((second & 0xC0) != 0x80 || (p[i + 1] & 0xC0) != 0x80 ||
			    (p[i + 2] & 0xC0) != 0x80)
				return false;
			if (lead == 0xF0 && second < 0x90)
				return false;
			if (lead == 0xF4 && second >= 0x90)
				return false;

			i += 3;
			continue;
		}

		return false;
	}

	return true;
}

@implementation NSStringTemplate

- (instancetype)init
{
	self = [super init];

	return (id)@"";
}

- (instancetype)initWithString:(NSString *)aString
{
	_NSRequireNonnil(aString);

	return (id)aString;
}

- (nullable instancetype)initWithCString:(char const *)nullTerminatedCString encoding:(NS8BitStringEncoding)encoding
{
	_NSRequireNonnullptr(nullTerminatedCString);

	switch (encoding) {
	case NS8BitASCIIStringEncoding:
	case NS8BitUTF8StringEncoding:
		return (id)[self initWithBytes:nullTerminatedCString length:strlen(nullTerminatedCString)
				encoding:(NSStringEncoding)encoding];
	}

	_NSRaiseException(MethodContext, NSInvalidArgumentException, @"encoding was invalid.");
}

- (nullable instancetype)initWithUTF8String:(char const *)utf8String
{
	_NSRequireNonnullptr(utf8String);

	return (id)[self initWithBytes:utf8String length:strlen(utf8String) encoding:NSUTF8StringEncoding];
}

- (instancetype)initWithFormat:(NSString *)format arguments:(__builtin_va_list)arguments
{
	NSStringBuilderResult r;

	_NSRequireNonnil(format);

	if (format.length == 0)
		return (id)@"";

	r = NSStringBuilder(NSStringBuilderEncodingUTF16, format, arguments);

	/* A non-empty format can still produce no output (e.g.: @"%.0d" of 0, or @"%s" of ""). */
	if (r.length == 0) {
		free(r.data.utf16);
		return (id)@"";
	}

	if (r.isASCII) {
		NSUInteger byteLength;
		char *ascii;

		if (__builtin_add_overflow(r.length, 1, &byteLength))
			abort();

		ascii = _NSMalloc(byteLength);

		for (NSUInteger k = 0; k < r.length; ++k)
			ascii[k] = (char)r.data.utf16[k];
		ascii[r.length] = '\0';

		free(r.data.utf16);

		return (id)[[NSASCIIString alloc] _initWithNullTerminatedBytesNoCopy:ascii length:r.length
				freeWhenDone:true];
	}

	return (id)[[NSUTF16String alloc] _initWithCharactersNoCopy:r.data.utf16 length:r.length freeWhenDone:true];
}

- (nullable instancetype)initWithBytes:(void const *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding
{
	_NSRequireNonnullptr(bytes);

	if (length == 0)
		return (id)@"";

	switch (encoding) {
	case NSASCIIStringEncoding:
		return (id)[[NSASCIIString alloc] _initWithBytes:bytes length:length];

	case NSUTF8StringEncoding: {
		NSUInteger units;
		unichar *utf16;

		if (UTF8IsValid(bytes, length) == false)
			return nil;

		units = NSUTF8CountUTF16Units(bytes, length);

		/* Pure ASCII. */
		if (units == length)
			return (id)[[NSASCIIString alloc] _initWithBytes:bytes length:length];

		utf16 = _NSMalloc(units * sizeof(unichar));
		ConvertUTF8ToUTF16(utf16, bytes, length);

		return (id)[[NSUTF16String alloc] _initWithCharactersNoCopy:utf16 length:units freeWhenDone:true];
	}

	case NSUTF16StringEncoding:
	case NSUTF16BigEndianStringEncoding:
	case NSUTF16LittleEndianStringEncoding:
		return (id)[[NSUTF16String alloc] _initWithBytes:bytes length:length encoding:encoding];
	}

	_NSRaiseException(MethodContext, NSInvalidArgumentException, @"encoding was invalid.");
}

- (nullable instancetype)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding freeWhenDone:(bool)freeBuffer
{
	_NSRequireNonnullptr(bytes);

	if (length == 0)
		return (id)@"";

	switch (encoding) {
	case NSASCIIStringEncoding:
		return (id)[[NSASCIIString alloc] _initWithBytesNoCopy:bytes length:length freeWhenDone:freeBuffer];

	case NSUTF8StringEncoding: {
		NSUInteger units;
		unichar *utf16;

		if (UTF8IsValid(bytes, length) == false) {
			if (freeBuffer)
				free(bytes);

			return nil;
		}

		units = NSUTF8CountUTF16Units(bytes, length);

		if (units == length)
			return (id)[[NSASCIIString alloc] _initWithBytesNoCopy:bytes length:length
				freeWhenDone:freeBuffer];

		/* Convert into a fresh buffer we own. */
		utf16 = _NSMalloc(units * sizeof(unichar));
		ConvertUTF8ToUTF16(utf16, bytes, length);

		if (freeBuffer)
			free(bytes);

		return (id)[[NSUTF16String alloc] _initWithCharactersNoCopy:utf16 length:units freeWhenDone:true];
	}

	case NSUTF16StringEncoding:
	case NSUTF16BigEndianStringEncoding:
	case NSUTF16LittleEndianStringEncoding:
		return (id)[[NSUTF16String alloc] _initWithBytesNoCopy:bytes length:length
				encoding:encoding freeWhenDone:freeBuffer];
	}

	_NSRaiseException(MethodContext, NSInvalidArgumentException, @"encoding was invalid.");
}

- (instancetype)initWithCharacters:(unichar const *)characters length:(NSUInteger)length
{
	_NSRequireNonnullptr(characters);

	if (length == 0)
		return (id)@"";

	return (id)[[NSUTF16String alloc] _initWithCharacters:characters length:length];
}

- (instancetype)initWithCharactersNoCopy:(unichar *)characters length:(NSUInteger)length freeWhenDone:(bool)freeBuffer
{
	_NSRequireNonnullptr(characters);

	if (length == 0)
		return (id)@"";

	return (id)[[NSUTF16String alloc] _initWithCharactersNoCopy:characters length:length freeWhenDone:freeBuffer];
}

@end

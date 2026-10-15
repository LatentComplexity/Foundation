
/*
 * TODO: Everything here must go once I find the time to reinvent libicu and bake in everything from scratch.
 * TODO: NSString exists in this sorry state only to appease NSException's public API surface and a few other things.
 * TODO: Currently, one should consider NSString as an implementation detail.
 */

#import <FoundationPrivate/NSString/NSString.h>

@implementation NSString

unsigned __int128 _NSStringHashKey = 0;
static NSStringTemplate *_NSStringTemplateInstance = nil;
Class _NSStringClass = Nil;
Class _NSStringTemplateClass = Nil;
Class _NSTaggedConstantStringClass = Nil;
Class _NSConstantStringClass = Nil;
Class _NSASCIIStringClass = Nil;
Class _NSUTF16StringClass = Nil;

/* Return the number of UTF-8 bytes needed for string, replacing malformed UTF-16 code units with U+FFFD. */
[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline NSUInteger
UTF8LengthOfString(NSString *__unsafe_unretained string)
{
	NSUInteger length;
	NSUInteger byteLength;

	length = string.length;
	byteLength = 0;

	for (NSUInteger i = 0; i < length; ++i) {
		unichar c;
		NSUInteger additional;

		c = [string characterAtIndex:i];

		if (c <= 0x007F)
			additional = 1;
		else if (c <= 0x07FF)
			additional = 2;
		else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < length) {
			unichar c2 = [string characterAtIndex:i + 1];

			if (c2 >= 0xDC00 && c2 <= 0xDFFF) {
				additional = 4;
				++i;
			} else
				additional = 3;
		} else
			additional = 3;

		if (__builtin_add_overflow(byteLength, additional, &byteLength))
			abort();
	}

	return byteLength;
}

/* Encode one Unicode scalar into output and return the next output position. */
[[clang::always_inline]]
static inline char *
AppendUTF8CodePoint(char *output, unsigned int codePoint)
{
	if (codePoint <= 0x7F) {
		*output++ = (char)codePoint;
	} else if (codePoint <= 0x7FF) {
		*output++ = (char)(0xC0 | (codePoint >> 6));
		*output++ = (char)(0x80 | (codePoint & 0x3F));
	} else if (codePoint <= 0xFFFF) {
		*output++ = (char)(0xE0 | (codePoint >> 12));
		*output++ = (char)(0x80 | ((codePoint >> 6) & 0x3F));
		*output++ = (char)(0x80 | (codePoint & 0x3F));
	} else {
		*output++ = (char)(0xF0 | (codePoint >> 18));
		*output++ = (char)(0x80 | ((codePoint >> 12) & 0x3F));
		*output++ = (char)(0x80 | ((codePoint >> 6) & 0x3F));
		*output++ = (char)(0x80 | (codePoint & 0x3F));
	}

	return output;
}

+ (void)initialize
{
	static NSCallOnceState s = { 0 };

	if (self == [NSString class])
		NSCallOnce(&s, ^{
			NSRandomBytes(&_NSStringHashKey, sizeof(_NSStringHashKey));
			_NSStringTemplateInstance = [NSStringTemplate alloc];
			_NSStringClass = [NSString class];
			_NSStringTemplateClass = [NSStringTemplate class];
			_NSTaggedConstantStringClass = [NSTaggedConstantString class];
			_NSConstantStringClass = [NSConstantString class];
			_NSASCIIStringClass = [NSASCIIString class];
			_NSUTF16StringClass = [NSUTF16String class];
		});
}

+ (instancetype)alloc
{
	if (self == _NSStringClass)
		return _NSStringTemplateInstance;

	return class_createInstance(self, 0);
}

- (id)copy
{
	return self;
}

+ (instancetype)string
{
	return @"";
}

+ (instancetype)stringWithString:(NSString *)aString
{
	return [[self alloc] initWithString:aString];
}

+ (nullable instancetype)stringWithCString:(char const *)cString encoding:(NS8BitStringEncoding)encoding
{
	return [[self alloc] initWithCString:cString encoding:encoding];
}

+ (nullable instancetype)stringWithUTF8String:(char const *)utf8String
{
	return [[self alloc] initWithUTF8String:utf8String];
}

+ (instancetype)stringWithFormat:(NSString *)format, ...
{
	__builtin_va_list arguments;
	NSString *obj;

	__builtin_va_start(arguments, format);

	obj = [[self alloc] initWithFormat:format arguments:arguments];

	__builtin_va_end(arguments);

	return obj;
}

+ (instancetype)stringWithCharacters:(unichar const *)characters length:(NSUInteger)length
{
	return [[self alloc] initWithCharacters:characters length:length];
}

- (instancetype)init
{
	return self;
}

- (instancetype)initWithString:(NSString *)aString
{
	_NSStringRejectReinitialization(MethodContext);
}

- (nullable instancetype)initWithCString:(char const *)nullTerminatedCString encoding:(NS8BitStringEncoding)encoding
{
	_NSStringRejectReinitialization(MethodContext);
}

- (nullable instancetype)initWithUTF8String:(char const *)utf8String
{
	_NSStringRejectReinitialization(MethodContext);
}

- (instancetype)initWithFormat:(NSString *)format, ...
{
	__builtin_va_list arguments;
	id obj;

	__builtin_va_start(arguments, format);
	obj = [self initWithFormat:format arguments:arguments];
	__builtin_va_end(arguments);

	return obj;
}

- (instancetype)initWithFormat:(NSString *)format arguments:(__builtin_va_list)arguments
{
	_NSStringRejectReinitialization(MethodContext);
}

- (nullable instancetype)initWithBytes:(void const *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding
{
	_NSStringRejectReinitialization(MethodContext);
}

- (nullable instancetype)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding freeWhenDone:(bool)freeBuffer
{
	_NSStringRejectReinitialization(MethodContext);
}

- (instancetype)initWithCharacters:(unichar const *)characters length:(NSUInteger)length
{
	_NSStringRejectReinitialization(MethodContext);
}

- (instancetype)initWithCharactersNoCopy:(unichar *)characters length:(NSUInteger)length freeWhenDone:(bool)freeBuffer
{
	_NSStringRejectReinitialization(MethodContext);
}

- (NSUInteger)length
{
	_NSStringRejectInvocation(MethodContext);
}

- (char const *)UTF8String
{
	char *utf8String;
	NSUInteger utf8StringLength;
	NSUInteger allocationLength;
	NSUInteger length;
	char *output;

	length = self.length;
	if (length == 0)
		return "";

	utf8StringLength = UTF8LengthOfString(self);
	if (__builtin_add_overflow(utf8StringLength, 1, &allocationLength))
		abort();

	utf8String = _NSMalloc(allocationLength);

	output = utf8String;
	for (NSUInteger i = 0; i < length; ++i) {
		unichar c;
		unsigned int codePoint;

		c = [self characterAtIndex:i];
		if (c >= 0xD800 && c <= 0xDBFF && i + 1 < length) {
			unichar c2 = [self characterAtIndex:i + 1];

			if (c2 >= 0xDC00 && c2 <= 0xDFFF) {
				codePoint = 0x10000U + (((unsigned int)c - 0xD800U) << 10) +
						((unsigned int)c2 - 0xDC00U);
				++i;
			} else
				codePoint = 0xFFFD;
		} else if (c >= 0xD800 && c <= 0xDFFF)
			codePoint = 0xFFFD;
		else
			codePoint = c;

		output = AppendUTF8CodePoint(output, codePoint);
	}

	*output = '\0';
	return (char const *)[[NSData dataWithBytesNoCopy:utf8String count:allocationLength freeWhenDone:true] bytes];
}

- (unichar)characterAtIndex:(NSUInteger)index
{
	_NSStringRejectInvocation(MethodContext);
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)range
{
	_NSRequireNonnullptr(buffer);

	/* TODO: Range checks before calling -characterAtIndex:! It will trap, but I'd rather do that early. */
	for (NSUInteger i = 0; i < range.length; ++i)
		buffer[i] = [self characterAtIndex:range.location + i];
}

- (nullable char const *)cStringUsingEncoding:(NS8BitStringEncoding)encoding
{
	/* If requested ASCII, grab all code units, malloc equal-sized buffer, iterate, check, and throw in. */
	/* If requested UTF-8, convert and spit out. */
	/* TODO: ... */
	return nullptr;
}

- (NSString *)description
{
	return self;
}

- (NSUInteger)hash
{
	NSSipHashContext c;
	NSUInteger h;
	NSUInteger length = self.length;

	NSSipHashContextInit(&c, _NSStringHashKey);
	NSSipHashWithContext(&c, (NSUInteger[]){ self.length }, sizeof(NSUInteger));

	for (NSUInteger i = 0; i < length; ++i)
		NSSipHashWithContext(&c, (unichar[]){ [self characterAtIndex:i] }, sizeof(unichar));

	NSSipHashWithContextFinalize(&c, &h);

	return h;
}

- (bool)isEqualToString:(NSString *)aString
{
	_NSRequireNonnil(aString);

	NSUInteger myLength;

	if ((uintptr_t)self == (uintptr_t)aString)
		return true;

	if ((myLength = self.length) != aString.length)
		return false;

	if (self.hash != aString.hash)
		return false;

	for (NSUInteger i = 0; i < myLength; ++i)
		if ([self characterAtIndex:i] != [aString characterAtIndex:i])
			return false;

	return true;
}

- (bool)isEqual:(id)anObject
{
	if ((uintptr_t)self == (uintptr_t)anObject)
			return true;

	if ([(id<NSObject>)anObject isKindOfClass:_NSStringClass])
		return [self isEqualToString:(NSString *)anObject];

	return false;
}

@end

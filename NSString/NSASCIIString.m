
#import <FoundationPrivate/NSString/NSString.h>

@interface NSASCIIString ()

@property (nonatomic, readonly) NSUInteger hash;
@property (nonatomic, readonly, direct) bool ownBytes;
@property (nonatomic, readonly, direct) bool freeWhenDone;
@property (nonatomic, readonly, direct) char *bytes;
@property (nonatomic, readonly, direct) char *UTF8Bytes;

@end

@implementation NSASCIIString

@synthesize hash = _hash;
@synthesize length = _length;
@synthesize ownBytes = _ownBytes;
@synthesize freeWhenDone = _freeWhenDone;
@synthesize bytes = _bytes;
@synthesize UTF8Bytes = _UTF8Bytes;

- (nullable instancetype)_initWithBytes:(char const *)bytes length:(NSUInteger)length OBJC_DIRECT
{
	NSUInteger byteLength;

	if (length < 9)
		return (id)[NSTaggedConstantString _stringWithBytes:bytes length:length];

	if (__builtin_add_overflow(length, 1, &byteLength))
		abort();

	_length = length;
	_ownBytes = true;
	_bytes = _NSMalloc(byteLength);

	memcpy(_bytes, bytes, length);
	_bytes[length] = '\0';
	_UTF8Bytes = _bytes;

	return self;
}

- (nullable instancetype)_initWithBytesNoCopy:(char *)bytes length:(NSUInteger)length
			freeWhenDone:(bool)freeBuffer OBJC_DIRECT
{
	NSUInteger byteLength;

	if (length < 9) {
		NSTaggedConstantString *obj = [NSTaggedConstantString _stringWithBytes:bytes length:length];
		if (freeBuffer == true)
			free(bytes);

		return (id)obj;
	}

	if (__builtin_add_overflow(length, 1, &byteLength))
		abort();

	_length = length;
	_freeWhenDone = freeBuffer;
	_bytes = (char *)(uintptr_t)bytes;
	_UTF8Bytes = _NSMalloc(byteLength);

	memcpy(_UTF8Bytes, bytes, length);
	_UTF8Bytes[length] = '\0';

	return self;
}

- (nullable instancetype)_initWithNullTerminatedBytesNoCopy:(char *)bytes length:(NSUInteger)length
			freeWhenDone:(bool)freeBuffer OBJC_DIRECT
{
	if (length < 9) {
		NSTaggedConstantString *obj = [NSTaggedConstantString _stringWithBytes:bytes length:length];
		if (freeBuffer == true)
			free(bytes);

		return (id)obj;
	}

	_length = length;
	_freeWhenDone = freeBuffer;
	_bytes = (char *)(uintptr_t)bytes;
	_UTF8Bytes = _bytes;

	return self;
}

- (char const *)UTF8String
{
	return _UTF8Bytes;
}

- (unichar)characterAtIndex:(NSUInteger)index
{
	if (index >= _length)
		_NSRaiseException(MethodContext, NSRangeException, @"index out of bounds.");

	return (unichar)_bytes[index];
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)range
{
	if (buffer == nullptr)
		abort();

	if (range.location > _length)
		abort();

	if (range.length == 0)
		return;

	if (NSRangeMax(range) > _length)
		abort();

	for (NSUInteger i = 0; i < range.length; ++i)
		buffer[i] = (unichar)_bytes[i];
}

- (nullable char const *)cStringUsingEncoding:(NS8BitStringEncoding)encoding
{
	switch (encoding) {
	case NS8BitASCIIStringEncoding:
	case NS8BitUTF8StringEncoding:
		return _UTF8Bytes;
	}

	_NSRaiseException(MethodContext, NSInvalidArgumentException, @"encoding was invalid.");
}

- (void)dealloc
{
	if (_UTF8Bytes != _bytes)
		free(_UTF8Bytes);

	if (_ownBytes)
		free(_bytes);
	else
		if (_freeWhenDone)
			free(_bytes);
}

@end

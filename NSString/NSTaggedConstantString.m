
/*
 * TO-DO: Find a more efficient way to scatter and re-assemble ASCII out of the pointer!
 */

#import <FoundationPrivate/NSString/NSString.h>

@implementation NSTaggedConstantString

+ (void)load
{
	if (objc_registerSmallObjectClass_np(self, NSTaggedConstantStringClass) == false)
		abort();
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-objc-pointer-introspection"

+ (instancetype)_stringWithBytes:(char const *)bytes length:(NSUInteger)length OBJC_DIRECT
{
	uintptr_t obj = 0;

	for (NSUInteger i = 0; i < length; ++i) {
		if (((unsigned char const *)bytes)[i] > 0x7F)
			return nil;

		obj |= ((uintptr_t)bytes[i] & 0x7F) << ((7 - i) * 7 + 8);
	}

	obj |= length << 3;
	obj |= NSTaggedConstantStringClass;

	return (__bridge NSTaggedConstantString *)(void *)obj;
}

#pragma clang diagnostic pop

- (NSUInteger)length [[clang::no_sanitize("integer")]]
{
	return ((uintptr_t)self << 56) >> 59;
}

- (char const *)UTF8String
{
	char bytes[9];
	NSUInteger length = ((uintptr_t)self << 56) >> 59;

	for (NSUInteger i = 0; i < length; ++i)
		bytes[i] = (char)((uintptr_t)self >> ((7 - i) * 7 + 8)) & 0x7F;
	bytes[length] = '\0';

	return [[NSData dataWithBytes:bytes count:length + 1] bytes];
}

- (unichar)characterAtIndex:(NSUInteger)index [[clang::no_sanitize("integer")]]
{
	if (index >= ((uintptr_t)self << 56) >> 59)
		_NSRaiseException(MethodContext, NSRangeException, @"index out of bounds.");

	return (unichar)((uintptr_t)self >> ((7 - index) * 7 + 8)) & 0x7F;
}

- (nullable char const *)cStringUsingEncoding:(NS8BitStringEncoding)encoding
{
	switch (encoding) {
	case NS8BitASCIIStringEncoding:
	case NS8BitUTF8StringEncoding:
		return [self UTF8String];
	}

	_NSRaiseException(MethodContext, NSInvalidArgumentException, @"encoding was invalid.");
}

@end


#import <FoundationPrivate/NSValue/NSValue.h>
#import <FoundationPrivate/NSObject/NSTypeEncodingString.h>

@implementation NSValueTemplate

- (instancetype)initWithBytes:(void const *)value objCType:(char const *)type
{
	_NSRequireNonnullptr(value);
	_NSRequireNonnullptr(type);

	if (*type == '\0')
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"'type' was empty.");

	NSTypeEncodingStringResult const r = NSTypeEncodingStringValidate(NSTypeEncodingStringSchemeStorable, type);
	if (r.status != NSTypeEncodingStringStatusOK)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"%@", r.reason);

	NSUInteger size;
	NSUInteger leafCount;
	char const *end;
	char const *next;

	end = next = NSTypeEncodingStringMeasure(type, &size, nullptr, &leafCount);
	/* TODO: parse the number as a whole and throw if it is non-sensical like in NSTypeEncodingStringValidate(). */
	while (*next >= '0' && *next <= '9')
		++next;

	if (*next != '\0')
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"'type' must hold a single value.");

	if (size == 0)
		_NSRaiseException(MethodContext, NSInvalidArgumentException,
			@"empty aggregates are a stain upon the C language.");

	if (size == sizeof(void *) && leafCount == 1) {
		void const *ptr = *(void *const *)value;

		if (type[0] == '^' && type[1] == 'v' && type[2] == '\0')
			return ptr ? (id)[NSVoidPointerValue _valueWithPointer:ptr] :
					(id)_NSNullVoidPointerValueInstance;
	}

	void *const valueBytes = _NSMalloc(size);
	memcpy(valueBytes, value, size);

	NSUInteger typeLength = (uintptr_t)end - (uintptr_t)type;
	char *valueType = _NSMalloc(typeLength + 1);
	memcpy(valueType, type, typeLength);
	valueType[typeLength] = '\0';

	return (id)[NSInlineValue _valueWithBytes:valueBytes size:size objCType:valueType];
}

@end

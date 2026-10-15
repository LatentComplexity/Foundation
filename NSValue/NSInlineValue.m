
#import <FoundationPrivate/NSValue/NSValue.h>
#import <FoundationPrivate/NSObject/NSTypeEncodingString.h>

@implementation NSInlineValue {
	void const *_bytes;
	NSUInteger _size;
	char const *_objCType;
	NSUInteger _Atomic _hash;
}

+ (instancetype)_valueWithBytes:(void const *)bytes size:(NSUInteger)size objCType:(char const *)type OBJC_DIRECT
{
	NSInlineValue *obj = class_createInstance(self, 0);
	obj->_bytes = bytes;
	obj->_size = size;
	obj->_objCType = type;

	return obj;
}

- (char const *)objCType
{
	return _objCType;
}

/* TODO: this should only return some value if the associated type is also pointer-sized. */
- (nullable void *)pointerValue
{
	if (_size == 8)
		return *(void *const *)_bytes;

	return nullptr;
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	_NSRequireNonnullptr(value);
	_NSValueRequireSizeMatchingType(size, _size, _objCType);

	memcpy(value, _bytes, size);
}

- (NSUInteger)hash
{
	NSUInteger h = OSAtomicLoad(&_hash, OSAtomicMemoryOrderRelaxed);

	if (h == 0) {
		NSSipHashContext c;

		NSSipHashContextInit(&c, _NSValueHashKey);
		NSSipHashWithContext(&c, _objCType, strlen(_objCType));
		NSSipHashWithContext(&c, _bytes, _size);
		NSSipHashWithContextFinalize(&c, &h);
		OSAtomicStore(&_hash, h, OSAtomicMemoryOrderRelaxed);
	}

	return h;
}

/* TODO: this will not work reliably because padding has no determinate value. */
- (bool)isEqualToValue:(NSValue *)aValue
{
	_NSRequireNonnil(aValue);

	if ((uintptr_t)self == (uintptr_t)aValue)
		return true;

	Class const c = object_getClass(aValue);

	if (c == _NSInlineValueClass) {
		NSInlineValueLayout *layout = (__bridge NSInlineValueLayout *)aValue;
		if (_size != layout->size || strcmp(_objCType, layout->objCType) != 0)
			return false;

		return memcmp(_bytes, layout->bytes, _size) == 0;
	}

	if (c == _NSNullVoidPointerValueClass || c == _NSVoidPointerValueClass)
		return false;

	char const *const otherType = aValue.objCType;
	if (strcmp(_objCType, otherType) != 0)
		return false;

	/* If both type strings are equal, then their sizes are also equal. */
	NSUInteger const otherSize = NSTypeEncodingStringSizeOf(otherType);
	void *const otherData = _NSMalloc(otherSize);
	[aValue getValue:otherData size:otherSize];

	bool const result = memcmp(_bytes, otherData, _size) == 0;

	free(otherData);

	return result;
}

- (void)dealloc
{
	free((void *)(uintptr_t)_bytes);
	free((void *)(uintptr_t)_objCType);
}

@end

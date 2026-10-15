
#import <FoundationPrivate/NSValue/NSValue.h>

@implementation NSVoidPointerValue {
	void const *_pointerValue;
}

+ (instancetype)_valueWithPointer:(void const *)pointer OBJC_DIRECT
{
	NSVoidPointerValue *obj = class_createInstance(self, 0);
	obj->_pointerValue = pointer;

	return obj;
}

- (char const *)objCType
{
	return @encode(void *);
}

- (nullable void *)pointerValue
{
	return (void *)(uintptr_t)_pointerValue;
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	_NSRequireNonnullptr(value);
	_NSValueRequireSizeMatchingType(size, sizeof(void *), "^v");

	*(void const **)value = _pointerValue;
}

- (NSUInteger)hash
{
	char buffer[10];

	buffer[0] = '^';
	buffer[1] = 'v';

	__builtin_memcpy_inline(buffer + 2, &_pointerValue, sizeof(uintptr_t));

	return NSSipHash(buffer, 10, _NSValueHashKey);
}

- (bool)isEqualToValue:(NSValue *)aValue
{
	_NSRequireNonnil(aValue);

	if ((uintptr_t)self == (uintptr_t)aValue)
		return true;

	if ((uintptr_t)_NSNullVoidPointerValueInstance == (uintptr_t)aValue)
		return false;

	Class const c = object_getClass(aValue);

	if (c == _NSVoidPointerValueClass)
		return _pointerValue == ((__bridge NSVoidPointerValueLayout *)aValue)->pointerValue;

	if (c == _NSInlineValueClass || c == _NSNullVoidPointerValueClass)
		return false;

	char const *otherType = aValue.objCType;
	if (otherType[0] == '^' && otherType[1] == 'v' && otherType[2] == '\0') {
		void *ptr;
		[aValue getValue:&ptr size:sizeof(void *)];
		return _pointerValue == ptr;
	}

	return false;
}

@end

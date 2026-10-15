
#import <FoundationPrivate/NSValue/NSValue.h>

@implementation NSNullVoidPointerValue

- (char const *)objCType
{
	return @encode(void *);
}

- (nullable void *)pointerValue
{
	return nullptr;
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	_NSRequireNonnullptr(value);
	_NSValueRequireSizeMatchingType(size, sizeof(void *), "^v");

	*(void **)value = nullptr;
}

- (NSUInteger)hash
{
	return _NSNullVoidPointerValueHash;
}

- (bool)isEqualToValue:(NSValue *)aValue
{
	_NSRequireNonnil(aValue);

	if ((uintptr_t)self == (uintptr_t)aValue)
		return true;

	Class const c = object_getClass(aValue);

	if (c == _NSInlineValueClass || c == _NSVoidPointerValueClass)
		return false;

	char const *otherType = aValue.objCType;
	if (otherType[0] == '^' && otherType[1] == 'v' && otherType[2] == '\0') {
		void *ptr;
		[aValue getValue:&ptr size:sizeof(void *)];
		return nullptr == ptr;
	}

	return false;
}

@end

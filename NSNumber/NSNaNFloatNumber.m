
#import <FoundationPrivate/NSNumber/NSNumber.h>

@implementation NSNaNFloatNumber

- (char const *)objCType
{
	return @encode(float);
}

- (void *)pointerValue
{
	return nullptr;
}

- (char)charValue
{
	return 0;
}

- (unsigned char)unsignedCharValue
{
	return 0;
}

- (short)shortValue
{
	return 0;
}

- (unsigned short)unsignedShortValue
{
	return 0;
}

- (int)intValue
{
	return 0;
}

- (unsigned int)unsignedIntValue
{
	return 0;
}

- (long)longValue
{
	return 0;
}

- (unsigned long)unsignedLongValue
{
	return 0;
}

- (long long)longLongValue
{
	return 0;
}

- (unsigned long long)unsignedLongLongValue
{
	return 0;
}

- (NSInteger)integerValue
{
	return 0;
}

- (NSUInteger)unsignedIntegerValue
{
	return 0;
}

- (bool)boolValue
{
	return false;
}

- (float)floatValue
{
	return __builtin_nanf("");
}

- (double)doubleValue
{
	return __builtin_nan("");
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	_NSRequireNonnullptr(value);
	_NSNumberRequireSizeMatchingType(size, sizeof(float), @encode(float));

	*(float *)value = __builtin_nanf("");
}

- (NSUInteger)hash
{
	return _NSNaNHash;
}

- (bool)isEqualToNumber:(NSNumber *)aNumber
{
	_NSRequireNonnil(aNumber);

	if ((uintptr_t)self == (uintptr_t)aNumber)
		return true;

	return __builtin_isnan(aNumber.floatValue);
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
	_NSRequireNonnil(otherNumber);

	if ((uintptr_t)self == (uintptr_t)otherNumber)
		return NSOrderedSame;

	return __builtin_isnan(otherNumber.doubleValue) ? NSOrderedSame : NSOrderedAscending;
}

- (NSString *)description
{
	return @"nan";
}

@end

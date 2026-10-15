
#import <FoundationPrivate/NSNumber/NSNumber.h>

@implementation NSPositiveInfinityFloatNumber

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
	return NSNumberCharMax;
}

- (unsigned char)unsignedCharValue
{
	return NSNumberUnsignedCharMax;
}

- (short)shortValue
{
	return NSNumberShortMax;
}

- (unsigned short)unsignedShortValue
{
	return NSNumberUnsignedShortMax;
}

- (int)intValue
{
	return NSNumberIntMax;
}

- (unsigned int)unsignedIntValue
{
	return NSNumberUnsignedIntMax;
}

- (long)longValue
{
	return NSNumberLongMax;
}

- (unsigned long)unsignedLongValue
{
	return NSNumberUnsignedLongMax;
}

- (long long)longLongValue
{
	return NSNumberLongLongMax;
}

- (unsigned long long)unsignedLongLongValue
{
	return NSNumberUnsignedLongLongMax;
}

- (NSInteger)integerValue
{
	return NSNumberLongMax;
}

- (NSUInteger)unsignedIntegerValue
{
	return NSNumberUnsignedLongMax;
}

- (bool)boolValue
{
	return true;
}

- (float)floatValue
{
	return __builtin_inff();
}

- (double)doubleValue
{
	return __builtin_inf();
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	_NSRequireNonnullptr(value);
	_NSNumberRequireSizeMatchingType(size, sizeof(float), @encode(float));

	*(float *)value = __builtin_inff();
}

- (NSUInteger)hash
{
	return _NSPositiveInfinityHash;
}

- (bool)isEqualToNumber:(NSNumber *)aNumber
{
	_NSRequireNonnil(aNumber);

	if ((uintptr_t)self == (uintptr_t)aNumber)
		return true;

	return __builtin_inf() == aNumber.doubleValue;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
	_NSRequireNonnil(otherNumber);

	if ((uintptr_t)self == (uintptr_t)otherNumber)
		return NSOrderedSame;

	double const otherValue = otherNumber.doubleValue;

	if (__builtin_isnan(otherValue))
		return NSOrderedDescending;

	if (__builtin_isinf(otherValue) && __builtin_signbit(otherValue) == false)
		return NSOrderedSame;

	return NSOrderedDescending;
}

- (NSString *)description
{
	return @"inf";
}

@end

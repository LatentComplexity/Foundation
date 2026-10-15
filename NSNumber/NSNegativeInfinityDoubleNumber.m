
#import <FoundationPrivate/NSNumber/NSNumber.h>

@implementation NSNegativeInfinityDoubleNumber

- (char const *)objCType
{
	return @encode(double);
}

- (void *)pointerValue
{
	return nullptr;
}

- (char)charValue
{
	return NSNumberCharMin;
}

- (unsigned char)unsignedCharValue
{
	return NSNumberUnsignedCharMin;
}

- (short)shortValue
{
	return NSNumberShortMin;
}

- (unsigned short)unsignedShortValue
{
	return NSNumberUnsignedShortMin;
}

- (int)intValue
{
	return NSNumberIntMin;
}

- (unsigned int)unsignedIntValue
{
	return NSNumberUnsignedIntMin;
}

- (long)longValue
{
	return NSNumberLongMin;
}

- (unsigned long)unsignedLongValue
{
	return NSNumberUnsignedLongMin;
}

- (long long)longLongValue
{
	return NSNumberLongLongMin;
}

- (unsigned long long)unsignedLongLongValue
{
	return NSNumberUnsignedLongLongMin;
}

- (NSInteger)integerValue
{
	return NSNumberLongMin;
}

- (NSUInteger)unsignedIntegerValue
{
	return NSNumberUnsignedLongMin;
}

- (bool)boolValue
{
	return false;
}

- (float)floatValue
{
	return -__builtin_inff();
}

- (double)doubleValue
{
	return -__builtin_inf();
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	_NSRequireNonnullptr(value);
	_NSNumberRequireSizeMatchingType(size, sizeof(double), @encode(double));

	*(double *)value = -__builtin_inf();
}

- (NSUInteger)hash
{
	return _NSNegativeInfinityHash;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wfloat-equal"

- (bool)isEqualToNumber:(NSNumber *)aNumber
{
	_NSRequireNonnil(aNumber);

	if ((uintptr_t)self == (uintptr_t)aNumber)
		return true;

	return -__builtin_inf() == aNumber.doubleValue;
}

#pragma clang diagnostic pop

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
	_NSRequireNonnil(otherNumber);

	if ((uintptr_t)self == (uintptr_t)otherNumber)
		return NSOrderedSame;

	double const otherValue = otherNumber.doubleValue;

	if (__builtin_isnan(otherValue))
		return NSOrderedDescending;

	if (__builtin_isinf(otherValue) && __builtin_signbit(otherValue))
		return NSOrderedSame;

	return NSOrderedAscending;
}

- (NSString *)description
{
	return @"-inf";
}

@end

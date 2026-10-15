
#import <FoundationPrivate/NSNumber/NSNumber.h>

@implementation NSDoubleNumber

@synthesize doubleValue = _doubleValue;

+ (instancetype)_numberWithDouble:(double)value OBJC_DIRECT
{
	NSDoubleNumber *obj = class_createInstance(self, 0);
	obj->_doubleValue = value;

	return obj;
}

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
	return _NSNumberCharValueFromFiniteDouble(_doubleValue);
}

- (unsigned char)unsignedCharValue
{
	return _NSNumberUnsignedCharValueFromFiniteDouble(_doubleValue);
}

- (short)shortValue
{
	return _NSNumberShortValueFromFiniteDouble(_doubleValue);
}

- (unsigned short)unsignedShortValue
{
	return _NSNumberUnsignedShortValueFromFiniteDouble(_doubleValue);
}

- (int)intValue
{
	return _NSNumberIntValueFromFiniteDouble(_doubleValue);
}

- (unsigned int)unsignedIntValue
{
	return _NSNumberUnsignedIntValueFromFiniteDouble(_doubleValue);
}

- (long)longValue
{
	return _NSNumberLongValueFromFiniteDouble(_doubleValue);
}

- (unsigned long)unsignedLongValue
{
	return _NSNumberUnsignedLongValueFromFiniteDouble(_doubleValue);
}

- (long long)longLongValue
{
	return _NSNumberLongLongValueFromFiniteDouble(_doubleValue);
}

- (unsigned long long)unsignedLongLongValue
{
	return _NSNumberUnsignedLongLongValueFromFiniteDouble(_doubleValue);
}

- (NSInteger)integerValue
{
	return (NSInteger)_NSNumberLongValueFromFiniteDouble(_doubleValue);
}

- (NSUInteger)unsignedIntegerValue
{
	return (NSUInteger)_NSNumberUnsignedLongValueFromFiniteDouble(_doubleValue);
}

- (bool)boolValue
{
	return (bool)_doubleValue;
}

- (float)floatValue
{
	/* NSDoubleNumber never holds NaN. */
	if (_doubleValue > (double)__FLT_MAX__)
		return __builtin_inff();
	if (_doubleValue < -(double)__FLT_MAX__)
		return -__builtin_inff();

	return (float)_doubleValue;
}

- (double)doubleValue
{
	return _doubleValue;
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	_NSRequireNonnullptr(value);
	_NSNumberRequireSizeMatchingType(size, sizeof(double), @encode(double));

	*(double *)value = _doubleValue;
}

- (NSUInteger)hash
{
	unsigned long valueBits;
	__builtin_memcpy_inline(&valueBits, &_doubleValue, sizeof(valueBits));
	return NSSipHash((NSUInteger[]) {
		NSNumberRepresentationDecimalValueType,
		valueBits,
		_doubleValue < 0
	}, sizeof(NSUInteger) * 3, _NSNumberHashKey);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wfloat-equal"

- (bool)isEqualToNumber:(NSNumber *)aNumber
{
	_NSRequireNonnil(aNumber);

	uintptr_t const otherptr = (uintptr_t)aNumber;

	if ((uintptr_t)self == otherptr)
		return true;

	if ((otherptr & 0b111) == NSTaggedIntegerNumberClass || (otherptr & 0b111) == NSTaggedFloatNumberClass)
		return false;

	Class const c = object_getClass(aNumber);

	if (c == _NSDoubleNumberClass)
		return _doubleValue == ((__bridge NSDoubleNumberLayout *)aNumber)->doubleValue;

	if (c == _NSPositiveIntegerNumberClass || c == _NSNegativeIntegerNumberClass ||
	    c == _NSNaNDoubleNumberClass || c == _NSNaNFloatNumberClass ||
	    c == _NSNegativeInfinityDoubleNumberClass || c == _NSNegativeInfinityFloatNumberClass ||
	    c == _NSPositiveInfinityDoubleNumberClass || c == _NSPositiveInfinityFloatNumberClass)
		return false;

	/* .isNegative isn't used for decimal comparisons, but it can't hurt to fill it in, no? */
	return _NSNumberRepresentationIsEqualToNumberRepresentation((NSNumberRepresentation) {
		.type = NSNumberRepresentationDecimalValueType,
		.value.d = _doubleValue,
		.isNegative = __builtin_signbit(_doubleValue)
	}, _NSNumberGetRepresentation(aNumber, aNumber.objCType[0]));
}

#pragma clang diagnostic pop

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
	_NSRequireNonnil(otherNumber);

	uintptr_t const otherptr = (uintptr_t)otherNumber;

	if ((uintptr_t)self == otherptr)
		return NSOrderedSame;

	if ((otherptr & 0b111) == NSTaggedIntegerNumberClass) {
		long long const otherValue = (long long)((intptr_t)otherptr >> NSTaggedIntegerNumberValueShift);
		return (NSComparisonResult)((_doubleValue > (double)otherValue) -
					(_doubleValue < (double)otherValue));
	}

	if ((otherptr & 0b111) == NSTaggedFloatNumberClass) {
		float otherValue;
		unsigned int const bits = (unsigned int)(otherptr >> NSTaggedFloatNumberShift);
		__builtin_memcpy_inline(&otherValue, &bits, sizeof(otherValue));

		return (NSComparisonResult)((_doubleValue > (double)otherValue) -
					(_doubleValue < (double)otherValue));
	}

	Class const c = object_getClass(otherNumber);

	if (c == _NSDoubleNumberClass) {
		double const otherValue = ((__bridge NSDoubleNumberLayout *)otherNumber)->doubleValue;
		return (NSComparisonResult)((_doubleValue > otherValue) - (_doubleValue < otherValue));
	}

	NSNumberRepresentation const rep = {
		.type = NSNumberRepresentationDecimalValueType,
		.value.d = _doubleValue,
		.isNegative = __builtin_signbit(_doubleValue)
	};

	if (c == _NSNegativeIntegerNumberClass) {
		long long const otherValue = ((__bridge NSNegativeIntegerNumberLayout *)otherNumber)->longLongValue;
		return _NSNumberRepresentationCompare(rep, (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = (unsigned long long)(-(otherValue + 1LL)) + 1ULL,
			.isNegative = true
		});
	}

	if (c == _NSPositiveIntegerNumberClass) {
		unsigned long long const otherValue =
			((__bridge NSPositiveIntegerNumberLayout *)otherNumber)->unsignedLongLongValue;
		return _NSNumberRepresentationCompare(rep, (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = otherValue,
			.isNegative = false
		});
	}

	if (c == _NSNegativeInfinityFloatNumberClass || c == _NSNegativeInfinityDoubleNumberClass)
		return NSOrderedDescending;

	if (c == _NSPositiveInfinityFloatNumberClass || c == _NSPositiveInfinityDoubleNumberClass)
		return NSOrderedAscending;

	if (c == _NSNaNFloatNumberClass || c == _NSNaNDoubleNumberClass)
		return NSOrderedDescending;

	return _NSNumberRepresentationCompare(rep, _NSNumberGetRepresentation(otherNumber, otherNumber.objCType[0]));
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%f", _doubleValue];
}

@end

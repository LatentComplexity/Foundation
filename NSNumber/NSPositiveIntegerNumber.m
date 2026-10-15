
#import <FoundationPrivate/NSNumber/NSNumber.h>

@implementation NSPositiveIntegerNumber

@synthesize objCType = _objCType;
@synthesize unsignedLongLongValue = _unsignedLongLongValue;

+ (instancetype)_numberWithLong:(long)value OBJC_DIRECT
{
	NSPositiveIntegerNumber *obj = class_createInstance(self, 0);
	obj->_objCType = @encode(long);
	obj->_unsignedLongLongValue = (unsigned long long)value;

	return obj;
}

+ (instancetype)_numberWithLongLong:(long long)value OBJC_DIRECT
{
	NSPositiveIntegerNumber *obj = class_createInstance(self, 0);
	obj->_objCType = @encode(long long);
	obj->_unsignedLongLongValue = (unsigned long long)value;

	return obj;
}

+ (instancetype)_numberWithUnsignedLong:(unsigned long)value OBJC_DIRECT
{
	NSPositiveIntegerNumber *obj = class_createInstance(self, 0);
	obj->_objCType = @encode(unsigned long);
	obj->_unsignedLongLongValue = (unsigned long long)value;

	return obj;
}

+ (instancetype)_numberWithUnsignedLongLong:(unsigned long long)value OBJC_DIRECT
{
	NSPositiveIntegerNumber *obj = class_createInstance(self, 0);
	obj->_objCType = @encode(unsigned long long);
	obj->_unsignedLongLongValue = value;

	return obj;
}

+ (instancetype)_numberWithIntegralFloat:(float)value OBJC_DIRECT
{
	NSPositiveIntegerNumber *obj = class_createInstance(self, 0);
	obj->_objCType = @encode(float);
	obj->_unsignedLongLongValue = (unsigned long long)value;

	return obj;
}

+ (instancetype)_numberWithIntegralDouble:(double)value OBJC_DIRECT
{
	NSPositiveIntegerNumber *obj = class_createInstance(self, 0);
	obj->_objCType = @encode(double);
	obj->_unsignedLongLongValue = (unsigned long long)value;

	return obj;
}

- (void *)pointerValue
{
	switch (_objCType[0]) {
	case 'l':
	case 'q':
	case 'L':
	case 'Q':
		return (void *)(uintptr_t)_unsignedLongLongValue;

	case 'f':
	case 'd':
		return nullptr;

	default:
		__builtin_trap();
	}
}

- (char)charValue
{
	return (char)_unsignedLongLongValue;
}

- (unsigned char)unsignedCharValue
{
	return (unsigned char)_unsignedLongLongValue;
}

- (short)shortValue
{
	return (short)_unsignedLongLongValue;
}

- (unsigned short)unsignedShortValue
{
	return (unsigned short)_unsignedLongLongValue;
}

- (int)intValue
{
	return (int)_unsignedLongLongValue;
}

- (unsigned int)unsignedIntValue
{
	return (unsigned int)_unsignedLongLongValue;
}

- (long)longValue
{
	return (long)_unsignedLongLongValue;
}

- (unsigned long)unsignedLongValue
{
	return (unsigned long)_unsignedLongLongValue;
}

- (long long)longLongValue
{
	return (long long)_unsignedLongLongValue;
}

- (unsigned long long)unsignedLongLongValue
{
	return (unsigned long long)_unsignedLongLongValue;
}

- (NSInteger)integerValue
{
	return (NSInteger)_unsignedLongLongValue;
}

- (NSUInteger)unsignedIntegerValue
{
	return (NSUInteger)_unsignedLongLongValue;
}

- (bool)boolValue
{
	return (bool)_unsignedLongLongValue;
}

- (float)floatValue
{
	return (float)_unsignedLongLongValue;
}

- (double)doubleValue
{
	return (double)_unsignedLongLongValue;
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	_NSRequireNonnullptr(value);

	switch (_objCType[0]) {
	case 'l':
		_NSNumberRequireSizeMatchingType(size, sizeof(long), @encode(long));

		*(long *)value = (long)_unsignedLongLongValue;
		return;

	case 'q':
		_NSNumberRequireSizeMatchingType(size, sizeof(long long), @encode(long long));

		*(long long *)value = (long long)_unsignedLongLongValue;
		return;

	case 'L':
		_NSNumberRequireSizeMatchingType(size, sizeof(unsigned long), @encode(unsigned long));

		*(unsigned long *)value = (unsigned long)_unsignedLongLongValue;
		return;

	case 'Q':
		_NSNumberRequireSizeMatchingType(size, sizeof(unsigned long long), @encode(unsigned long long));

		*(unsigned long long *)value = _unsignedLongLongValue;
		return;

	case 'f':
		_NSNumberRequireSizeMatchingType(size, sizeof(float), @encode(float));

		*(float *)value = (float)_unsignedLongLongValue;
		return;

	case 'd':
		_NSNumberRequireSizeMatchingType(size, sizeof(double), @encode(double));

		*(double *)value = (double)_unsignedLongLongValue;
		return;

	default:
		__builtin_trap();
	}
}

- (NSUInteger)hash
{
	return NSSipHash((NSUInteger[]) {
		NSNumberRepresentationIntegerValueType,
		_unsignedLongLongValue,
		false
	}, sizeof(NSUInteger) * 3, _NSNumberHashKey);
}

- (bool)isEqualToNumber:(NSNumber *)aNumber
{
	_NSRequireNonnil(aNumber);

	if ((uintptr_t)self == (uintptr_t)aNumber)
		return true;

	Class const c = object_getClass(aNumber);
	if (c == _NSPositiveIntegerNumberClass)
		return _unsignedLongLongValue ==
			((__bridge NSPositiveIntegerNumberLayout *)aNumber)->unsignedLongLongValue;

	if (c == _NSTaggedFloatNumberClass || c == _NSTaggedIntegerNumberClass ||
	    c == _NSDoubleNumberClass || c == _NSNaNDoubleNumberClass || c == _NSNaNFloatNumberClass ||
	    c == _NSNegativeInfinityDoubleNumberClass || c == _NSNegativeInfinityFloatNumberClass ||
	    c == _NSPositiveInfinityDoubleNumberClass || c == _NSPositiveInfinityFloatNumberClass ||
	    c == _NSNegativeIntegerNumberClass)
		return false;

	return _NSNumberRepresentationIsEqualToNumberRepresentation((NSNumberRepresentation) {
		.type = NSNumberRepresentationIntegerValueType,
		.value.u = _unsignedLongLongValue,
		.isNegative = false
	}, _NSNumberGetRepresentation(aNumber, aNumber.objCType[0]));
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
	_NSRequireNonnil(otherNumber);

	uintptr_t const otherptr = (uintptr_t)otherNumber;

	if ((uintptr_t)self == otherptr)
		return NSOrderedSame;

	/* Heap-backed positive integers are strictly above the tagged-integer payload range. */
	if ((otherptr & 0b111) == NSTaggedIntegerNumberClass)
		return NSOrderedDescending;

	NSNumberRepresentation const rep = {
		.type = NSNumberRepresentationIntegerValueType,
		.value.u = _unsignedLongLongValue,
		.isNegative = false
	};

	if ((otherptr & 0b111) == NSTaggedFloatNumberClass) {
		float otherValue;
		unsigned int const bits = (unsigned int)(otherptr >> NSTaggedFloatNumberShift);
		__builtin_memcpy_inline(&otherValue, &bits, sizeof(otherValue));

		return _NSNumberRepresentationCompare(rep, (NSNumberRepresentation) {
			.type = NSNumberRepresentationDecimalValueType,
			.value.d = (double)otherValue,
			.isNegative = __builtin_signbit(otherValue)
		});
	}

	Class const c = object_getClass(otherNumber);

	if (c == _NSPositiveIntegerNumberClass) {
		unsigned long long const otherValue =
			((__bridge NSPositiveIntegerNumberLayout *)otherNumber)->unsignedLongLongValue;
		return (NSComparisonResult)((_unsignedLongLongValue > otherValue) -
					(_unsignedLongLongValue < otherValue));
	}

	if (c == _NSNegativeIntegerNumberClass)
		return NSOrderedDescending;

	if (c == _NSDoubleNumberClass) {
		double const otherValue = ((__bridge NSDoubleNumberLayout *)otherNumber)->doubleValue;
		return _NSNumberRepresentationCompare(rep, (NSNumberRepresentation) {
			.type = NSNumberRepresentationDecimalValueType,
			.value.d = otherValue,
			.isNegative = __builtin_signbit(otherValue)
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

@end

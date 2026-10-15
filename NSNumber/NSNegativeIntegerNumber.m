
#import <FoundationPrivate/NSNumber/NSNumber.h>

@implementation NSNegativeIntegerNumber

@synthesize objCType = _objCType;
@synthesize longLongValue = _longLongValue;

+ (instancetype)_numberWithLong:(long)value OBJC_DIRECT
{
	NSNegativeIntegerNumber *obj = class_createInstance(self, 0);
	obj->_objCType = @encode(long);
	obj->_longLongValue = (long long)value;

	return obj;
}

+ (instancetype)_numberWithLongLong:(long long)value OBJC_DIRECT
{
	NSNegativeIntegerNumber *obj = class_createInstance(self, 0);
	obj->_objCType = @encode(long long);
	obj->_longLongValue = value;

	return obj;
}

+ (instancetype)_numberWithIntegralFloat:(float)value OBJC_DIRECT
{
	NSNegativeIntegerNumber *obj = class_createInstance(self, 0);
	obj->_objCType = @encode(float);
	obj->_longLongValue = (long long)value;

	return obj;
}

+ (instancetype)_numberWithIntegralDouble:(double)value OBJC_DIRECT
{
	NSNegativeIntegerNumber *obj = class_createInstance(self, 0);
	obj->_objCType = @encode(double);
	obj->_longLongValue = (long long)value;

	return obj;
}

- (void *)pointerValue
{
	switch (_objCType[0]) {
	case 'l':
	case 'q':
		return (void *)(uintptr_t)_longLongValue;

	case 'f':
	case 'd':
		return nullptr;

	default:
		__builtin_trap();
	}
}

- (char)charValue
{
	return (char)_longLongValue;
}

- (unsigned char)unsignedCharValue
{
	return (unsigned char)_longLongValue;
}

- (short)shortValue
{
	return (short)_longLongValue;
}

- (unsigned short)unsignedShortValue
{
	return (unsigned short)_longLongValue;
}

- (int)intValue
{
	return (int)_longLongValue;
}

- (unsigned int)unsignedIntValue
{
	return (unsigned int)_longLongValue;
}

- (long)longValue
{
	return (long)_longLongValue;
}

- (unsigned long)unsignedLongValue
{
	return (unsigned long)_longLongValue;
}

- (long long)longLongValue
{
	return (long long)_longLongValue;
}

- (unsigned long long)unsignedLongLongValue
{
	return (unsigned long long)_longLongValue;
}

- (NSInteger)integerValue
{
	return (NSInteger)_longLongValue;
}

- (NSUInteger)unsignedIntegerValue
{
	return (NSUInteger)_longLongValue;
}

- (bool)boolValue
{
	return (bool)_longLongValue;
}

- (float)floatValue
{
	return (float)_longLongValue;
}

- (double)doubleValue
{
	return (double)_longLongValue;
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	_NSRequireNonnullptr(value);

	switch (_objCType[0]) {
	case 'l':
		_NSNumberRequireSizeMatchingType(size, sizeof(long), @encode(long));

		*(long *)value = (long)_longLongValue;
		return;

	case 'q':
		_NSNumberRequireSizeMatchingType(size, sizeof(long long), @encode(long long));

		*(long long *)value = _longLongValue;
		return;

	case 'f':
		_NSNumberRequireSizeMatchingType(size, sizeof(float), @encode(float));

		*(float *)value = (float)_longLongValue;
		return;

	case 'd':
		_NSNumberRequireSizeMatchingType(size, sizeof(double), @encode(double));

		*(double *)value = (double)_longLongValue;
		return;

	default:
		__builtin_trap();
	}
}

- (NSUInteger)hash
{
	return NSSipHash((NSUInteger[]) {
		NSNumberRepresentationIntegerValueType,
		(unsigned long long)(-(_longLongValue + 1LL)) + 1ULL,
		true
	}, sizeof(NSUInteger) * 3, _NSNumberHashKey);
}

- (bool)isEqualToNumber:(NSNumber *)aNumber
{
	_NSRequireNonnil(aNumber);

	if ((uintptr_t)self == (uintptr_t)aNumber)
		return true;

	Class const c = object_getClass(aNumber);
	if (c == _NSNegativeIntegerNumberClass)
		return _longLongValue == ((__bridge NSNegativeIntegerNumberLayout *)aNumber)->longLongValue;

	if (c == _NSTaggedFloatNumberClass || c == _NSTaggedIntegerNumberClass ||
	    c == _NSDoubleNumberClass || c == _NSNaNDoubleNumberClass || c == _NSNaNFloatNumberClass ||
	    c == _NSNegativeInfinityDoubleNumberClass || c == _NSNegativeInfinityFloatNumberClass ||
	    c == _NSPositiveInfinityDoubleNumberClass || c == _NSPositiveInfinityFloatNumberClass ||
	    c == _NSPositiveIntegerNumberClass)
		return false;

	return _NSNumberRepresentationIsEqualToNumberRepresentation((NSNumberRepresentation) {
		.type = NSNumberRepresentationIntegerValueType,
		.value.u = (unsigned long long)(-(_longLongValue + 1LL)) + 1ULL,
		.isNegative = true
	}, _NSNumberGetRepresentation(aNumber, aNumber.objCType[0]));
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
	_NSRequireNonnil(otherNumber);

	uintptr_t const otherptr = (uintptr_t)otherNumber;

	if ((uintptr_t)self == otherptr)
		return NSOrderedSame;

	/* Heap-backed negative integers are strictly below the tagged-integer payload range. */
	if ((otherptr & 0b111) == NSTaggedIntegerNumberClass)
		return NSOrderedAscending;

	NSNumberRepresentation const rep = {
		.type = NSNumberRepresentationIntegerValueType,
		.value.u = (unsigned long long)(-(_longLongValue + 1LL)) + 1ULL,
		.isNegative = true
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

	if (c == _NSNegativeIntegerNumberClass) {
		long long const otherValue = ((__bridge NSNegativeIntegerNumberLayout *)otherNumber)->longLongValue;
		return (NSComparisonResult)((_longLongValue > otherValue) - (_longLongValue < otherValue));
	}

	if (c == _NSPositiveIntegerNumberClass)
		return NSOrderedAscending;

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

- (NSString *)description
{
	return [NSString stringWithFormat:@"%lld", _longLongValue];
}

@end

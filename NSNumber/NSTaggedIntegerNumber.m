
#import <FoundationPrivate/NSNumber/NSNumber.h>

/* [63:9] signed integer value | [8] unused | [7] are we -0.0? | [6:3] type | [2:0] class tag */

@implementation NSTaggedIntegerNumber

+ (void)load
{
	static NSCallOnceState s = { 0 };

	NSCallOnce(&s, ^{
		if (objc_registerSmallObjectClass_np(self, NSTaggedIntegerNumberClass) == false)
			abort();
	});
}

[[clang::always_inline]]
static inline NSTaggedIntegerNumber *
_NSTaggedIntegerNumberWithValue(uintptr_t const value, NSTaggedIntegerNumberType const type, bool const negativeZero)
{
	/* Truncate to the payload width before shifting so no high bits are discarded by the shift. */
	uintptr_t obj = (value & (NSUIntegerMax >> NSTaggedIntegerNumberValueShift)) << NSTaggedIntegerNumberValueShift;

	if (negativeZero)
		obj |= (uintptr_t)NSTaggedIntegerNumberNegativeZeroFlag;

	obj |= (uintptr_t)type << NSTaggedIntegerNumberTypeShift;
	obj |= NSTaggedIntegerNumberClass;

	return (__bridge NSTaggedIntegerNumber *)(void *)obj;
}

+ (instancetype)_numberWithChar:(char)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeChar, false);
}

+ (instancetype)_numberWithUnsignedChar:(unsigned char)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeUnsignedChar, false);
}

+ (instancetype)_numberWithShort:(short)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeShort, false);
}

+ (instancetype)_numberWithUnsignedShort:(unsigned short)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeUnsignedShort, false);
}

+ (instancetype)_numberWithInt:(int)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeInt, false);
}

+ (instancetype)_numberWithUnsignedInt:(unsigned int)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeUnsignedInt, false);
}

+ (instancetype)_numberWithLong:(long)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeLong, false);
}

+ (instancetype)_numberWithUnsignedLong:(unsigned long)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeUnsignedLong, false);
}

+ (instancetype)_numberWithLongLong:(long long)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeLongLong, false);
}

+ (instancetype)_numberWithUnsignedLongLong:(unsigned long long)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeUnsignedLongLong, false);
}

+ (instancetype)_numberWithBool:(bool)value OBJC_DIRECT
{
	return _NSTaggedIntegerNumberWithValue((uintptr_t)value, NSTaggedIntegerNumberTypeBool, false);
}

+ (instancetype)_numberWithIntegralFloat:(float)value OBJC_DIRECT
{
	long long const signedValue = (long long)value;
	bool const negativeZero = value == 0.0f && __builtin_signbit(value);

	return _NSTaggedIntegerNumberWithValue((uintptr_t)signedValue, NSTaggedIntegerNumberTypeFloat, negativeZero);
}

+ (instancetype)_numberWithIntegralDouble:(double)value OBJC_DIRECT
{
	long long const signedValue = (long long)value;
	bool const negativeZero = value == 0.0 && __builtin_signbit(value);

	return _NSTaggedIntegerNumberWithValue((uintptr_t)signedValue, NSTaggedIntegerNumberTypeDouble, negativeZero);
}

- (char const *)objCType
{
	switch ((NSTaggedIntegerNumberType)(((intptr_t)self >> NSTaggedIntegerNumberTypeShift) & 0b1111)) {
	case NSTaggedIntegerNumberTypeChar:
		return @encode(char);
	case NSTaggedIntegerNumberTypeShort:
		return @encode(short);
	case NSTaggedIntegerNumberTypeInt:
		return @encode(int);
	case NSTaggedIntegerNumberTypeLong:
		return @encode(long);
	case NSTaggedIntegerNumberTypeLongLong:
		return @encode(long long);
	case NSTaggedIntegerNumberTypeUnsignedChar:
		return @encode(unsigned char);
	case NSTaggedIntegerNumberTypeUnsignedShort:
		return @encode(unsigned short);
	case NSTaggedIntegerNumberTypeUnsignedInt:
		return @encode(unsigned int);
	case NSTaggedIntegerNumberTypeUnsignedLong:
		return @encode(unsigned long);
	case NSTaggedIntegerNumberTypeUnsignedLongLong:
		return @encode(unsigned long long);
	case NSTaggedIntegerNumberTypeBool:
		return @encode(bool);
	case NSTaggedIntegerNumberTypeFloat:
		return @encode(float);
	case NSTaggedIntegerNumberTypeDouble:
		return @encode(double);
	}
}

#define NSTaggedIntegerNumberValue ((intptr_t)self >> NSTaggedIntegerNumberValueShift)

- (void *)pointerValue
{
	switch ((unsigned char)(((intptr_t)self >> NSTaggedIntegerNumberTypeShift) & 0b1111)) {
	case NSTaggedIntegerNumberTypeLong:
	case NSTaggedIntegerNumberTypeLongLong:
	case NSTaggedIntegerNumberTypeUnsignedLong:
	case NSTaggedIntegerNumberTypeUnsignedLongLong:
		return (void *)NSTaggedIntegerNumberValue;

	case NSTaggedIntegerNumberTypeChar:
	case NSTaggedIntegerNumberTypeShort:
	case NSTaggedIntegerNumberTypeInt:
	case NSTaggedIntegerNumberTypeUnsignedChar:
	case NSTaggedIntegerNumberTypeUnsignedShort:
	case NSTaggedIntegerNumberTypeUnsignedInt:
	case NSTaggedIntegerNumberTypeBool:
	case NSTaggedIntegerNumberTypeFloat:
	case NSTaggedIntegerNumberTypeDouble:
		return nullptr;

	default:
		__builtin_trap();
	}
}

- (char)charValue
{
	return (char)NSTaggedIntegerNumberValue;
}

- (unsigned char)unsignedCharValue
{
	return (unsigned char)NSTaggedIntegerNumberValue;
}

- (short)shortValue
{
	return (short)NSTaggedIntegerNumberValue;
}

- (unsigned short)unsignedShortValue
{
	return (unsigned short)NSTaggedIntegerNumberValue;
}

- (int)intValue
{
	return (int)NSTaggedIntegerNumberValue;
}

- (unsigned int)unsignedIntValue
{
	return (unsigned int)NSTaggedIntegerNumberValue;
}

- (long)longValue
{
	return (long)NSTaggedIntegerNumberValue;
}

- (unsigned long)unsignedLongValue
{
	return (unsigned long)NSTaggedIntegerNumberValue;
}

- (long long)longLongValue
{
	return (long long)NSTaggedIntegerNumberValue;
}

- (unsigned long long)unsignedLongLongValue
{
	return (unsigned long long)NSTaggedIntegerNumberValue;
}

- (NSInteger)integerValue
{
	return (long)NSTaggedIntegerNumberValue;
}

- (NSUInteger)unsignedIntegerValue
{
	return (unsigned long)NSTaggedIntegerNumberValue;
}

- (bool)boolValue
{
	return (bool)NSTaggedIntegerNumberValue;
}

- (float)floatValue
{
	return (intptr_t)self & NSTaggedIntegerNumberNegativeZeroFlag ? -0.0f : (float)NSTaggedIntegerNumberValue;
}

- (double)doubleValue
{
	return (intptr_t)self & NSTaggedIntegerNumberNegativeZeroFlag ? -0.0 : (double)NSTaggedIntegerNumberValue;
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	intptr_t const ptr = (intptr_t)self;
	long long const signedValue = ptr >> NSTaggedIntegerNumberValueShift;
	_NSRequireNonnullptr(value);

	switch ((unsigned char)((ptr >> NSTaggedIntegerNumberTypeShift) & 0b1111)) {
	case NSTaggedIntegerNumberTypeChar:
		_NSNumberRequireSizeMatchingType(size, sizeof(char), @encode(char));

		*(char *)value = (char)signedValue;
		return;

	case NSTaggedIntegerNumberTypeShort:
		_NSNumberRequireSizeMatchingType(size, sizeof(short), @encode(short));

		*(short *)value = (short)signedValue;
		return;

	case NSTaggedIntegerNumberTypeInt:
		_NSNumberRequireSizeMatchingType(size, sizeof(int), @encode(int));

		*(int *)value = (int)signedValue;
		return;

	case NSTaggedIntegerNumberTypeLong:
		_NSNumberRequireSizeMatchingType(size, sizeof(long), @encode(long));

		*(long *)value = (long)signedValue;
		return;

	case NSTaggedIntegerNumberTypeLongLong:
		_NSNumberRequireSizeMatchingType(size, sizeof(long long), @encode(long long));

		*(long long *)value = (long long)signedValue;
		return;

	case NSTaggedIntegerNumberTypeUnsignedChar:
		_NSNumberRequireSizeMatchingType(size, sizeof(unsigned char), @encode(unsigned char));

		*(unsigned char *)value = (unsigned char)signedValue;
		return;

	case NSTaggedIntegerNumberTypeUnsignedShort:
		_NSNumberRequireSizeMatchingType(size, sizeof(unsigned short), @encode(unsigned short));

		*(unsigned short *)value = (unsigned short)signedValue;
		return;

	case NSTaggedIntegerNumberTypeUnsignedInt:
		_NSNumberRequireSizeMatchingType(size, sizeof(unsigned int), @encode(unsigned int));

		*(unsigned int *)value = (unsigned int)signedValue;
		return;

	case NSTaggedIntegerNumberTypeUnsignedLong:
		_NSNumberRequireSizeMatchingType(size, sizeof(unsigned long), @encode(unsigned long));

		*(unsigned long *)value = (unsigned long)signedValue;
		return;

	case NSTaggedIntegerNumberTypeUnsignedLongLong:
		_NSNumberRequireSizeMatchingType(size, sizeof(unsigned long long), @encode(unsigned long long));

		*(unsigned long long *)value = (unsigned long long)signedValue;
		return;

	case NSTaggedIntegerNumberTypeBool:
		_NSNumberRequireSizeMatchingType(size, sizeof(bool), @encode(bool));

		*(bool *)value = (bool)signedValue;
		return;

	case NSTaggedIntegerNumberTypeFloat:
		_NSNumberRequireSizeMatchingType(size, sizeof(float), @encode(float));

		*(float *)value = ptr & NSTaggedIntegerNumberNegativeZeroFlag ? -0.0f : (float)signedValue;
		return;

	case NSTaggedIntegerNumberTypeDouble:
		_NSNumberRequireSizeMatchingType(size, sizeof(double), @encode(double));

		*(double *)value = ptr & NSTaggedIntegerNumberNegativeZeroFlag ? -0.0 : (double)signedValue;
		return;

	default:
		__builtin_trap();
	}
}

- (NSUInteger)hash
{
	long long value = (long long)NSTaggedIntegerNumberValue;

	return NSSipHash((NSUInteger[]) {
		NSNumberRepresentationIntegerValueType,
		value < 0 ? (unsigned long long)-value : (unsigned long long)value,
		value < 0
	}, sizeof(NSUInteger) * 3, _NSNumberHashKey);
}

- (bool)isEqualToNumber:(NSNumber *)aNumber
{
	_NSRequireNonnil(aNumber);

	intptr_t const ptr = (intptr_t)self;
	intptr_t const otherptr = (intptr_t)aNumber;

	if (ptr == otherptr)
		return true;

	if ((otherptr & 0b111) == NSTaggedIntegerNumberClass)
		return ptr >> NSTaggedIntegerNumberValueShift == otherptr >> NSTaggedIntegerNumberValueShift;

	if ((otherptr & 0b111) == NSTaggedFloatNumberClass)
		return false;

	Class const c = object_getClass(aNumber);

	if (c == _NSPositiveIntegerNumberClass || c == _NSNegativeIntegerNumberClass || c == _NSDoubleNumberClass ||
	    c == _NSNaNDoubleNumberClass || c == _NSNaNFloatNumberClass ||
	    c == _NSNegativeInfinityDoubleNumberClass || c == _NSNegativeInfinityFloatNumberClass ||
	    c == _NSPositiveInfinityDoubleNumberClass || c == _NSPositiveInfinityFloatNumberClass)
		return false;

	long long const value = (long long)NSTaggedIntegerNumberValue;

	return _NSNumberRepresentationIsEqualToNumberRepresentation((NSNumberRepresentation) {
		.type = NSNumberRepresentationIntegerValueType,
		.value.u = value < 0 ? (unsigned long long)-value : (unsigned long long)value,
		.isNegative = value < 0
	}, _NSNumberGetRepresentation(aNumber, aNumber.objCType[0]));
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
	_NSRequireNonnil(otherNumber);

	intptr_t const ptr = (intptr_t)self;
	intptr_t const otherptr = (intptr_t)otherNumber;

	if (ptr == otherptr)
		return NSOrderedSame;

	long long const value = (long long)NSTaggedIntegerNumberValue;

	if ((otherptr & 0b111) == NSTaggedIntegerNumberClass) {
		long long const otherValue = (long long)((intptr_t)otherptr >> NSTaggedIntegerNumberValueShift);
		return (NSComparisonResult)((value > otherValue) - (value < otherValue));
	}

	if ((otherptr & 0b111) == NSTaggedFloatNumberClass) {
		float otherValue;
		unsigned int const bits = (unsigned int)(otherptr >> NSTaggedFloatNumberShift);
		__builtin_memcpy_inline(&otherValue, &bits, sizeof(otherValue));

		return _NSNumberRepresentationCompare((NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = value < 0 ? (unsigned long long)-value : (unsigned long long)value,
			.isNegative = value < 0
		}, (NSNumberRepresentation) {
			.type = NSNumberRepresentationDecimalValueType,
			.value.d = (double)otherValue,
			.isNegative = otherValue < 0
		});
	}

	Class const c = object_getClass(otherNumber);

	/* Heap-backed integers lie strictly outside the tagged-integer payload range. */
	if (c == _NSNegativeIntegerNumberClass)
		return NSOrderedDescending;

	if (c == _NSPositiveIntegerNumberClass)
		return NSOrderedAscending;

	if (c == _NSDoubleNumberClass) {
		double const otherValue = ((__bridge NSDoubleNumberLayout *)otherNumber)->doubleValue;
		return _NSNumberRepresentationCompare((NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = value < 0 ? (unsigned long long)-value : (unsigned long long)value,
			.isNegative = value < 0
		}, (NSNumberRepresentation) {
			.type = NSNumberRepresentationDecimalValueType,
			.value.d = otherValue,
			.isNegative = otherValue < 0
		});
	}

	if (c == _NSNegativeInfinityFloatNumberClass || c == _NSNegativeInfinityDoubleNumberClass)
		return NSOrderedDescending;

	if (c == _NSPositiveInfinityFloatNumberClass || c == _NSPositiveInfinityDoubleNumberClass)
		return NSOrderedAscending;

	if (c == _NSNaNFloatNumberClass || c == _NSNaNDoubleNumberClass)
		return NSOrderedDescending;

	return _NSNumberRepresentationCompare((NSNumberRepresentation) {
		.type = NSNumberRepresentationIntegerValueType,
		.value.u = value < 0 ? (unsigned long long)-value : (unsigned long long)value,
		.isNegative = value < 0
	}, _NSNumberGetRepresentation(otherNumber, otherNumber.objCType[0]));
}

- (NSString *)description
{
	intptr_t const ptr = (intptr_t)self;
	long long const value = (long long)NSTaggedIntegerNumberValue;

	switch ((unsigned char)((ptr >> NSTaggedIntegerNumberTypeShift) & 0b1111)) {
	case NSTaggedIntegerNumberTypeChar:
	case NSTaggedIntegerNumberTypeShort:
	case NSTaggedIntegerNumberTypeInt:
	case NSTaggedIntegerNumberTypeLong:
	case NSTaggedIntegerNumberTypeLongLong:
	case NSTaggedIntegerNumberTypeUnsignedChar:
	case NSTaggedIntegerNumberTypeUnsignedShort:
	case NSTaggedIntegerNumberTypeUnsignedInt:
	case NSTaggedIntegerNumberTypeUnsignedLong:
	case NSTaggedIntegerNumberTypeUnsignedLongLong:
	case NSTaggedIntegerNumberTypeBool:
		return [NSString stringWithFormat:@"%lld", value];

	case NSTaggedIntegerNumberTypeFloat:
	case NSTaggedIntegerNumberTypeDouble:
		if ((ptr & NSTaggedIntegerNumberNegativeZeroFlag) != 0)
			return @"-0.0";
		return [NSString stringWithFormat:@"%lld", value];

	default:
		__builtin_trap();
	}
}

#undef NSTaggedIntegerNumberValue

@end

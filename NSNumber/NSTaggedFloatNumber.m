
#import <FoundationPrivate/NSNumber/NSNumber.h>

@implementation NSTaggedFloatNumber

+ (void)load
{
	static NSCallOnceState s = {};

	NSCallOnce(&s, ^{
		if (objc_registerSmallObjectClass_np(self, NSTaggedFloatNumberClass) == false)
			abort();
	});
}

+ (instancetype)_numberWithFloat:(float)value OBJC_DIRECT
{
	unsigned int bits;

	__builtin_memcpy_inline(&bits, &value, sizeof(unsigned int));
	uintptr_t obj = (uintptr_t)bits << NSTaggedFloatNumberShift;
	obj |= NSTaggedFloatNumberClass;

	return (__bridge NSTaggedFloatNumber *)(void *)obj;
}

+ (instancetype)_numberWithDouble:(double)value OBJC_DIRECT
{
	unsigned int bits;
	float const v = (float)value;

	__builtin_memcpy_inline(&bits, &v, sizeof(unsigned int));
	uintptr_t obj = (uintptr_t)bits << NSTaggedFloatNumberShift;
	obj |= NSTaggedFloatNumberIsDouble;
	obj |= NSTaggedFloatNumberClass;

	return (__bridge NSTaggedFloatNumber *)(void *)obj;
}

- (char const *)objCType
{
	return ((uintptr_t)self & NSTaggedFloatNumberIsDouble) == 0 ? @encode(float) : @encode(double);
}

- (void *)pointerValue
{
	return nullptr;
}

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline void
_NSTaggedFloatNumberExtractFloat(NSTaggedFloatNumber *obj, float *const f)
{
	unsigned int const bits = (unsigned int)((uintptr_t)obj >> NSTaggedFloatNumberShift);
	__builtin_memcpy_inline(f, &bits, sizeof(f));
}

- (char)charValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return _NSNumberCharValueFromFiniteDouble((double)f);
}

- (unsigned char)unsignedCharValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (unsigned char)_NSNumberUnsignedIntegerValueFromFiniteDouble((double)f, NSNumberCharBitWidth);
}

- (short)shortValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (short)_NSNumberSignedIntegerValueFromFiniteDouble((double)f, NSNumberShortBitWidth);
}

- (unsigned short)unsignedShortValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (unsigned short)_NSNumberUnsignedIntegerValueFromFiniteDouble((double)f, NSNumberShortBitWidth);
}

- (int)intValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (int)_NSNumberSignedIntegerValueFromFiniteDouble((double)f, NSNumberIntBitWidth);
}

- (unsigned int)unsignedIntValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (unsigned int)_NSNumberUnsignedIntegerValueFromFiniteDouble((double)f, NSNumberIntBitWidth);
}

- (long)longValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (long)_NSNumberSignedIntegerValueFromFiniteDouble((double)f, NSNumberLongBitWidth);
}

- (unsigned long)unsignedLongValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (unsigned long)_NSNumberUnsignedIntegerValueFromFiniteDouble((double)f, NSNumberLongBitWidth);
}

- (long long)longLongValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (long long)_NSNumberSignedIntegerValueFromFiniteDouble((double)f, NSNumberLongLongBitWidth);
}

- (unsigned long long)unsignedLongLongValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (unsigned long long)_NSNumberUnsignedIntegerValueFromFiniteDouble((double)f, NSNumberLongLongBitWidth);
}

- (NSInteger)integerValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (NSInteger)_NSNumberSignedIntegerValueFromFiniteDouble((double)f, NSNumberLongBitWidth);
}

- (NSUInteger)unsignedIntegerValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (NSUInteger)_NSNumberUnsignedIntegerValueFromFiniteDouble((double)f, NSNumberLongBitWidth);
}

- (bool)boolValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (bool)f;
}

- (float)floatValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return f;
}

- (double)doubleValue
{
	float f;
	_NSTaggedFloatNumberExtractFloat(self, &f);
	return (double)f;
}

- (void)getValue:(void *)value size:(NSUInteger)size
{
	float f;
	uintptr_t const ptr = (uintptr_t)self;
	unsigned int const bits = (unsigned int)(ptr >> NSTaggedFloatNumberShift);
	_NSRequireNonnullptr(value);

	__builtin_memcpy_inline(&f, &bits, sizeof(f));

	if ((ptr & NSTaggedFloatNumberIsDouble) == 0) {
		_NSNumberRequireSizeMatchingType(size, sizeof(float), @encode(float));

		*(float *)value = f;
	} else {
		_NSNumberRequireSizeMatchingType(size, sizeof(double), @encode(double));

		*(double *)value = (double)f;
	}
}

- (NSUInteger)hash
{
	float value;
	unsigned int const bits = (unsigned int)((uintptr_t)self >> NSTaggedFloatNumberShift);
	__builtin_memcpy_inline(&value, &bits, sizeof(value));
	unsigned long valueBits;
	double doubleValue = (double)value;
	__builtin_memcpy_inline(&valueBits, &doubleValue, sizeof(valueBits));

	return NSSipHash((NSUInteger[]) {
		NSNumberRepresentationDecimalValueType,
		valueBits,
		doubleValue < 0
	}, sizeof(NSUInteger) * 3, _NSNumberHashKey);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wfloat-equal"

- (bool)isEqualToNumber:(NSNumber *)aNumber
{
	_NSRequireNonnil(aNumber);

	uintptr_t const ptr = (uintptr_t)self;
	uintptr_t const otherptr = (uintptr_t)aNumber;

	if (ptr == otherptr)
		return true;

	float value;
	unsigned int const bits = (unsigned int)(ptr >> NSTaggedFloatNumberShift);
	__builtin_memcpy_inline(&value, &bits, sizeof(value));

	if ((otherptr & 0b111) == NSTaggedFloatNumberClass) {
		float otherValue;
		unsigned int const otherBits = (unsigned int)(otherptr >> NSTaggedFloatNumberShift);
		__builtin_memcpy_inline(&otherValue, &otherBits, sizeof(otherValue));

		return value == otherValue;
	}

	if ((otherptr & 0b111) == NSTaggedIntegerNumberClass)
		return false;

	Class const c = object_getClass(aNumber);

	if (c == _NSPositiveIntegerNumberClass || c == _NSNegativeIntegerNumberClass ||
	    c == _NSDoubleNumberClass || c == _NSNaNDoubleNumberClass || c == _NSNaNFloatNumberClass ||
	    c == _NSNegativeInfinityDoubleNumberClass || c == _NSNegativeInfinityFloatNumberClass ||
	    c == _NSPositiveInfinityDoubleNumberClass || c == _NSPositiveInfinityFloatNumberClass)
		return false;

	return _NSNumberRepresentationIsEqualToNumberRepresentation((NSNumberRepresentation) {
		.type = NSNumberRepresentationDecimalValueType,
		.value.d = (double)value,
		.isNegative = value < 0
	}, _NSNumberGetRepresentation(aNumber, aNumber.objCType[0]));
}

#pragma clang diagnostic pop

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
	_NSRequireNonnil(otherNumber);

	uintptr_t const ptr = (uintptr_t)self;
	uintptr_t const otherptr = (uintptr_t)otherNumber;

	if (ptr == otherptr)
		return NSOrderedSame;

	float value;
	unsigned int bits = (unsigned int)(ptr >> NSTaggedFloatNumberShift);
	__builtin_memcpy_inline(&value, &bits, sizeof(value));
	double const doubleValue = (double)value;

	if ((otherptr & 0b111) == NSTaggedFloatNumberClass) {
		float otherValue;
		bits = (unsigned int)(otherptr >> NSTaggedFloatNumberShift);
		__builtin_memcpy_inline(&otherValue, &bits, sizeof(otherValue));

		return (NSComparisonResult)((value > otherValue) - (value < otherValue));
	}

	if ((otherptr & 0b111) == NSTaggedIntegerNumberClass) {
		long long const otherValue = (long long)((intptr_t)otherptr >> NSTaggedIntegerNumberValueShift);
		return (NSComparisonResult)((doubleValue > (double)otherValue) -
					(doubleValue < (double)otherValue));
	}

	Class const c = object_getClass(otherNumber);

	if (c == _NSDoubleNumberClass) {
		double const otherValue = ((__bridge NSDoubleNumberLayout *)otherNumber)->doubleValue;
		return (NSComparisonResult)((doubleValue > otherValue) - (doubleValue < otherValue));
	}

	NSNumberRepresentation const rep = {
		.type = NSNumberRepresentationDecimalValueType,
		.value.d = doubleValue,
		.isNegative = __builtin_signbit(value)
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
	float f;
	unsigned int const bits = (unsigned int)((uintptr_t)self >> NSTaggedFloatNumberShift);
	__builtin_memcpy_inline(&f, &bits, sizeof(f));

	return [NSString stringWithFormat:@"%f", (double)f];
}

@end

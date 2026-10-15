
#import <Foundation/NSValue.h>
#import <FoundationPrivate/NSObject/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Classes

@interface NSNumberTemplate : NSNumber
@end

@interface NSDoubleNumber : NSNumber

+ (instancetype)_numberWithDouble:(double)value OBJC_DIRECT;

@end

@interface NSNaNDoubleNumber : NSNumber
@end

@interface NSNaNFloatNumber : NSNumber
@end

@interface NSNegativeInfinityDoubleNumber : NSNumber
@end

@interface NSNegativeInfinityFloatNumber : NSNumber
@end

@interface NSNegativeIntegerNumber : NSNumber

+ (instancetype)_numberWithLong:(long)value OBJC_DIRECT;
+ (instancetype)_numberWithLongLong:(long long)value OBJC_DIRECT;
+ (instancetype)_numberWithIntegralFloat:(float)value OBJC_DIRECT;
+ (instancetype)_numberWithIntegralDouble:(double)value OBJC_DIRECT;

@end

@interface NSPositiveInfinityDoubleNumber : NSNumber
@end

@interface NSPositiveInfinityFloatNumber : NSNumber
@end

@interface NSPositiveIntegerNumber : NSNumber

+ (instancetype)_numberWithLong:(long)value OBJC_DIRECT;
+ (instancetype)_numberWithLongLong:(long long)value OBJC_DIRECT;
+ (instancetype)_numberWithUnsignedLong:(unsigned long)value OBJC_DIRECT;
+ (instancetype)_numberWithUnsignedLongLong:(unsigned long long)value OBJC_DIRECT;
+ (instancetype)_numberWithIntegralFloat:(float)value OBJC_DIRECT;
+ (instancetype)_numberWithIntegralDouble:(double)value OBJC_DIRECT;

@end

@interface NSTaggedFloatNumber : NSNumber

+ (instancetype)_numberWithFloat:(float)value OBJC_DIRECT;
+ (instancetype)_numberWithDouble:(double)value OBJC_DIRECT;

@end

@interface NSTaggedIntegerNumber : NSNumber

+ (instancetype)_numberWithChar:(char)value OBJC_DIRECT;
+ (instancetype)_numberWithUnsignedChar:(unsigned char)value OBJC_DIRECT;
+ (instancetype)_numberWithShort:(short)value OBJC_DIRECT;
+ (instancetype)_numberWithUnsignedShort:(unsigned short)value OBJC_DIRECT;
+ (instancetype)_numberWithInt:(int)value OBJC_DIRECT;
+ (instancetype)_numberWithUnsignedInt:(unsigned int)value OBJC_DIRECT;
+ (instancetype)_numberWithLong:(long)value OBJC_DIRECT;
+ (instancetype)_numberWithUnsignedLong:(unsigned long)value OBJC_DIRECT;
+ (instancetype)_numberWithLongLong:(long long)value OBJC_DIRECT;
+ (instancetype)_numberWithUnsignedLongLong:(unsigned long long)value OBJC_DIRECT;
+ (instancetype)_numberWithBool:(bool)value OBJC_DIRECT;
+ (instancetype)_numberWithIntegralFloat:(float)value OBJC_DIRECT;
+ (instancetype)_numberWithIntegralDouble:(double)value OBJC_DIRECT;

@end

typedef struct [[gnu::may_alias]] NSDoubleNumberLayout {
	void const *const isa;
	double const doubleValue;
} NSDoubleNumberLayout;

typedef struct [[gnu::may_alias]] NSNegativeIntegerNumberLayout {
	void const *const isa;
	char const *const objCType;
	long long const longLongValue;
} NSNegativeIntegerNumberLayout;

typedef struct [[gnu::may_alias]] NSPositiveIntegerNumberLayout {
	void const *const isa;
	char const *const objCType;
	unsigned long long const unsignedLongLongValue;
} NSPositiveIntegerNumberLayout;

#pragma mark - Constants

#if defined(__CHAR_UNSIGNED__)
enum : char {
	NSNumberCharMin = 0,
	NSNumberCharMax = 255U
};
#else
enum : char {
	NSNumberCharMin = -127 - 1,
	NSNumberCharMax = 127
};
#endif

enum : unsigned char {
	NSNumberUnsignedCharMin = 0U,
	NSNumberUnsignedCharMax = 255U
};

enum : short {
	NSNumberShortMin = -32767 - 1,
	NSNumberShortMax = 32767
};

enum : unsigned short {
	NSNumberUnsignedShortMin = 0U,
	NSNumberUnsignedShortMax = 65535U
};

enum : int {
	NSNumberIntMin = -2147483647 - 1,
	NSNumberIntMax = 2147483647
};

enum : unsigned int {
	NSNumberUnsignedIntMin = 0U,
	NSNumberUnsignedIntMax = 4294967295U
};

enum : long {
	NSNumberLongMin = -9223372036854775807L - 1L,
	NSNumberLongMax = 9223372036854775807L
};

enum : unsigned long {
	NSNumberUnsignedLongMin = 0UL,
	NSNumberUnsignedLongMax = 18446744073709551615UL
};

enum : long long {
	NSNumberLongLongMin = -9223372036854775807LL - 1LL,
	NSNumberLongLongMax = 9223372036854775807LL
};

enum : unsigned long long {
	NSNumberUnsignedLongLongMin = 0ULL,
	NSNumberUnsignedLongLongMax = 18446744073709551615ULL
};

enum : uintptr_t {
	NSTaggedIntegerNumberClass = 0b001,
	NSTaggedFloatNumberClass = 0b010
};

enum : long long {
	NSTaggedIntegerNumberMax = 9007199254740992LL
};

[[gnu::visibility("hidden")]]
extern unsigned __int128 _NSNumberHashKey;

[[gnu::visibility("hidden")]]
extern NSUInteger _NSNaNHash;

[[gnu::visibility("hidden")]]
extern NSUInteger _NSNegativeInfinityHash;

[[gnu::visibility("hidden")]]
extern NSUInteger _NSPositiveInfinityHash;

[[gnu::visibility("hidden")]]
extern Class _NSDoubleNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSNaNDoubleNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSNaNFloatNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSNegativeInfinityDoubleNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSNegativeInfinityFloatNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSNegativeIntegerNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSPositiveInfinityDoubleNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSPositiveInfinityFloatNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSPositiveIntegerNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSTaggedFloatNumberClass;

[[gnu::visibility("hidden")]]
extern Class _NSTaggedIntegerNumberClass;

#pragma mark - Singletons

[[gnu::visibility("hidden")]]
extern NSNaNDoubleNumber *_NSNaNDoubleNumberInstance;

[[gnu::visibility("hidden")]]
extern NSNaNFloatNumber *_NSNaNFloatNumberInstance;

[[gnu::visibility("hidden")]]
extern NSNegativeInfinityDoubleNumber *_NSNegativeInfinityDoubleNumberInstance;

[[gnu::visibility("hidden")]]
extern NSNegativeInfinityFloatNumber *_NSNegativeInfinityFloatNumberInstance;

[[gnu::visibility("hidden")]]
extern NSPositiveInfinityDoubleNumber *_NSPositiveInfinityDoubleNumberInstance;

[[gnu::visibility("hidden")]]
extern NSPositiveInfinityFloatNumber *_NSPositiveInfinityFloatNumberInstance;

[[gnu::visibility("hidden")]]
extern NSTaggedIntegerNumber *_NSBooleanFalseNumberInstance;

[[gnu::visibility("hidden")]]
extern NSTaggedIntegerNumber *_NSBooleanTrueNumberInstance;

#pragma mark - Validation

[[clang::always_inline]]
static inline void
_NSCNumberRequireSizeMatchingType(NSMethodContext const context, NSUInteger const inputSize,
	NSUInteger const valueSize, char const *const objCType)
{
	if (inputSize != valueSize)
		_NSRaiseException(context, NSInvalidArgumentException,
			@"expected size of %lu bytes to match type encoding '%s', received size of %lu bytes.",
				valueSize, objCType, inputSize);
}

#define _NSNumberRequireSizeMatchingType(inputSize, valueSize, objCType) \
	_NSCNumberRequireSizeMatchingType(MethodContext, inputSize, valueSize, objCType)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCNumberRejectReinitialization(NSMethodContext const context)
{
	_NSClusterRejectReinitialization(context, _NSNumberClass,
		(NSClassSpan) {
			.classes = (Class[]){ _NSTaggedIntegerNumberClass, _NSTaggedFloatNumberClass,
				_NSNegativeIntegerNumberClass, _NSPositiveIntegerNumberClass, _NSDoubleNumberClass,
				_NSNaNFloatNumberClass, _NSNaNDoubleNumberClass, _NSNegativeInfinityFloatNumberClass,
				_NSPositiveInfinityFloatNumberClass, _NSNegativeInfinityDoubleNumberClass,
				_NSPositiveInfinityDoubleNumberClass },
			.count = 11
		}, _NSSubclassingPermitted);
}

#define _NSNumberRejectReinitialization() \
	_NSCNumberRejectReinitialization(MethodContext)

typedef enum NSTaggedIntegerNumberType : intptr_t {
	NSTaggedIntegerNumberTypeChar = 1,
	NSTaggedIntegerNumberTypeShort,
	NSTaggedIntegerNumberTypeInt,
	NSTaggedIntegerNumberTypeLong,
	NSTaggedIntegerNumberTypeLongLong,
	NSTaggedIntegerNumberTypeUnsignedChar,
	NSTaggedIntegerNumberTypeUnsignedShort,
	NSTaggedIntegerNumberTypeUnsignedInt,
	NSTaggedIntegerNumberTypeUnsignedLong,
	NSTaggedIntegerNumberTypeUnsignedLongLong,
	NSTaggedIntegerNumberTypeBool,
	NSTaggedIntegerNumberTypeFloat,
	NSTaggedIntegerNumberTypeDouble
} NSTaggedIntegerNumberType;

enum {
	NSTaggedIntegerNumberTypeShift = 3,
	NSTaggedIntegerNumberValueShift = 9
};

enum : intptr_t {
	NSTaggedIntegerNumberNegativeZeroFlag = 1UL << 7
};

enum {
	NSTaggedFloatNumberShift = 4
};

enum : uintptr_t {
	NSTaggedFloatNumberIsDouble = 1UL << 3
};

#pragma mark - Generics

typedef enum NSNumberRepresentationValueType : unsigned char {
	NSNumberRepresentationIntegerValueType = 0,
	NSNumberRepresentationDecimalValueType = 1,
} NSNumberRepresentationValueType;

/*
 * A vast majority of these structures are aggregate initialized, and so it would be very wise to NOT hash them
 * directly. They WILL contain padding holding bits with indeterminate values.
 *
 * To make matters worse, C23 now says the behaviour of assigning `{}` is to zero out all fields and padding. But,
 * what about the venerable `{ 0 }`? Haha. Nope. That zeroes out the fields but NOT the padding. Way to go, C. I,
 * stupidly, also make heavy use of aggregate initialization throughout NSNumber, which also does NOT clear padding.
 *
 * For hashing, the following:
 *
 * return NSSipHash((NSUInteger[]){ rep.type, isNegative, rep.value.u, }, sizeof(NSUInteger) * 3, _NSNumberHashKey);
 *
 * should suffice.
 */

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpadded"

typedef struct NSNumberRepresentation {
	NSNumberRepresentationValueType type;
	union {
		unsigned long long u;
		double d;
	} value;
	bool isNegative;
} NSNumberRepresentation;

#pragma clang diagnostic pop

[[clang::always_inline]]
static inline NSNumberRepresentation
_NumberGetDecimalRepresentation(double const v)
{
	/* Are we an integer in disguise? */
	if (v == __builtin_trunc(v)) {
		if (v >= -0x1p63 && v < 0.0) {
			long long const lv = (long long)v;
			return (NSNumberRepresentation) {
				.type = NSNumberRepresentationIntegerValueType,
				.value.u = (unsigned long long)(-(lv + 1LL)) + 1ULL,
				.isNegative = true
			};
		} else if (v >= 0.0 && v < 0x1p64) {
			return (NSNumberRepresentation) {
				.type = NSNumberRepresentationIntegerValueType,
				.value.u = (unsigned long long)v,
				.isNegative = false
			};
		}
	}

	/* NaN can technically have a sign and other junk in it, so we treat it as a special case. */
	if (__builtin_isnan(v))
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationDecimalValueType,
			.value.d = __builtin_nan(""),
			.isNegative = false
		};

	/* TODO: can't we delete this and use the return value below? */
	if (__builtin_isinf(v))
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationDecimalValueType,
			.value.d = __builtin_signbit(v) ? -__builtin_inf() : __builtin_inf(),
			.isNegative = __builtin_signbit(v)
		};



	return (NSNumberRepresentation) {
		.type = NSNumberRepresentationDecimalValueType,
		.value.d = v,
		.isNegative = __builtin_signbit(v)
	};
}

/*
 * Get a canonical representation of the object's number. Integers are represented by their sign and magnitude.
 * Floats are upcasted to doubles. Any decimal that can be represented by an exact integer is converted to an
 * integer.
 */
[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline NSNumberRepresentation
_NSNumberGetRepresentation(NSNumber *__unsafe_unretained aNumber, char const type)
{
	switch (type) {
#if defined (__CHAR_UNSIGNED__)
	case 'c':
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = (unsigned long long)aNumber.charValue,
			.isNegative = false
		};
#else
	/* Casting and negating works on types that cannot ever reach -2^63 and overflow their negation. */
	case 'c': {
		char const v;
		[aNumber getValue:&v size:sizeof(char)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = v < 0 ? (unsigned long long)(-(long long)v) : (unsigned long long)v,
			.isNegative = v < 0
		};
	}
#endif
	case 's': {
		short v;
		[aNumber getValue:&v size:sizeof(short)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = v < 0 ? (unsigned long long)(-(long long)v) : (unsigned long long)v,
			.isNegative = v < 0
		};
	}
	case 'i': {
		int v;
		[aNumber getValue:&v size:sizeof(int)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = v < 0 ? (unsigned long long)(-(long long)v) : (unsigned long long)v,
			.isNegative = v < 0
		};
	}
	/* For types that can reach -2^63, we handle them specially. */
	case 'l': {
		long v;
		[aNumber getValue:&v size:sizeof(long)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = v < 0 ? (unsigned long long)(-(v + 1LL)) + 1ULL : (unsigned long long)v,
			.isNegative = v < 0
		};
	}
	case 'q': {
		long long v;
		[aNumber getValue:&v size:sizeof(long long)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = v < 0 ? (unsigned long long)(-(v + 1LL)) + 1ULL : (unsigned long long)v,
			.isNegative = v < 0
		};
	}
	/* Signed types require no handling. */
	case 'C': {
		unsigned char v;
		[aNumber getValue:&v size:sizeof(unsigned char)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = (unsigned long long)v,
			.isNegative = false
		};
	}
	case 'S': {
		unsigned short v;
		[aNumber getValue:&v size:sizeof(unsigned short)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = (unsigned long long)v,
			.isNegative = false
		};
	}
	case 'I': {
		unsigned int v;
		[aNumber getValue:&v size:sizeof(unsigned int)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = (unsigned long long)v,
			.isNegative = false
		};
	}
	case 'L': {
		unsigned long v;
		[aNumber getValue:&v size:sizeof(unsigned long)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = (unsigned long long)v,
			.isNegative = false
		};
	}
	case 'Q': {
		unsigned long long v;
		[aNumber getValue:&v size:sizeof(unsigned long long)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = (unsigned long long)v,
			.isNegative = false
		};
	}
	case 'B': {
		bool v;
		[aNumber getValue:&v size:sizeof(bool)];
		return (NSNumberRepresentation) {
			.type = NSNumberRepresentationIntegerValueType,
			.value.u = (unsigned long long)v,
			.isNegative = false
		};
	}
	case 'f': {
		float v;
		[aNumber getValue:&v size:sizeof(float)];
		return _NumberGetDecimalRepresentation((double)v);
	}
	case 'd': {
		double v;
		[aNumber getValue:&v size:sizeof(double)];
		return _NumberGetDecimalRepresentation(v);
	}
	default:
		[NSException raise:NSInternalInconsistencyException format:@"invalid type encoding."];
	}

	__builtin_trap();
}

#pragma mark - Initializers

typedef union NSLargeCNumber {
	long long ll;
	unsigned long long ull;
} NSLargeCNumber;

/* Shared by NSNumber and NSNumberTemplate for initializing large integer number objects. */
[[clang::always_inline]]
static inline id
_NSLargeNumberWithType(NSLargeCNumber value, char type)
{
	switch (type) {
	case 'l': {
		if (value.ll >= -NSTaggedIntegerNumberMax && value.ll <= NSTaggedIntegerNumberMax)
			return [NSTaggedIntegerNumber _numberWithLong:(long)value.ll];
		return value.ll < 0 ? [NSNegativeIntegerNumber _numberWithLong:value.ll] :
					[NSPositiveIntegerNumber _numberWithLong:value.ll];
	}
	case 'q': {
		if (value.ll >= -NSTaggedIntegerNumberMax && value.ll <= NSTaggedIntegerNumberMax)
			return [NSTaggedIntegerNumber _numberWithLongLong:value.ll];
		return value.ll < 0 ? [NSNegativeIntegerNumber _numberWithLongLong:value.ll] :
					[NSPositiveIntegerNumber _numberWithLongLong:value.ll];
	}
	case 'L': {
		if (value.ull <= (unsigned long)NSTaggedIntegerNumberMax)
			return [NSTaggedIntegerNumber _numberWithUnsignedLong:value.ull];
		return [NSPositiveIntegerNumber _numberWithUnsignedLong:value.ull];
	}
	case 'Q': {
		if (value.ull <= (unsigned long long)NSTaggedIntegerNumberMax)
			return [NSTaggedIntegerNumber _numberWithUnsignedLongLong:value.ull];
		return [NSPositiveIntegerNumber _numberWithUnsignedLongLong:value.ull];
	}
	default:
		__builtin_trap();
	}
}

[[clang::always_inline]]
static inline id
_NSNumberWithFloat(float const value)
{
	/* Are we holding an integer? */
	if (value == __builtin_truncf(value)) {
		double const d = (double)value;
		if (d >= -0x1p53 && d <= 0x1p53)
			return (id)[NSTaggedIntegerNumber _numberWithIntegralFloat:value];
		if (d > 0x1p53 && d < 0x1p64)
			return (id)[NSPositiveIntegerNumber _numberWithIntegralFloat:value];
		if (d >= -0x1p63 && d < -0x1p53)
			return (id)[NSNegativeIntegerNumber _numberWithIntegralFloat:value];
	}

	/* NaN is special. */
	if (__builtin_isnan(value))
		return (id)_NSNaNFloatNumberInstance;

	/* +-infinity is special. */
	if (__builtin_isinf(value))
		return __builtin_signbit(value) ?
			_NSNegativeInfinityFloatNumberInstance : _NSPositiveInfinityFloatNumberInstance;

	/* Non-integer or out-of-integer-range stored directly as a float. */
	return (id)[NSTaggedFloatNumber _numberWithFloat:value];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wfloat-equal"

[[clang::always_inline]]
static inline id
_NSNumberWithDouble(double const value)
{
	/* Are we holding an integer? */
	if (value == __builtin_trunc(value)) {
		if (value >= -0x1p53 && value <= 0x1p53)
			return (id)[NSTaggedIntegerNumber _numberWithIntegralDouble:value];
		if (value > 0x1p53 && value < 0x1p64)
			return (id)[NSPositiveIntegerNumber _numberWithIntegralDouble:value];
		if (value >= -0x1p63 && value < -0x1p53)
			return (id)[NSNegativeIntegerNumber _numberWithIntegralDouble:value];
	}

	/* NaN is special. */
	if (__builtin_isnan(value))
		return (id)_NSNaNDoubleNumberInstance;

	/* +-infinity is special. */
	if (__builtin_isinf(value))
		return __builtin_signbit(value) ?
			_NSNegativeInfinityDoubleNumberInstance : _NSPositiveInfinityDoubleNumberInstance;

	/* A double that can be represented as a float with no loss of precision is stored as a float. */
	if (value >= -(double)__FLT_MAX__ && value <= (double)__FLT_MAX__ && (double)(float)value == value)
		return (id)[NSTaggedFloatNumber _numberWithDouble:value];

	/* An integer exceeding machine bounds, or a double with fractional bits set. */
	return (id)[NSDoubleNumber _numberWithDouble:value];
}

#pragma clang diagnostic pop

#pragma mark - Getters

typedef enum NSNumberBitWidth : unsigned char {
	NSNumberCharBitWidth = 8,
	NSNumberShortBitWidth = 16,
	NSNumberIntBitWidth = 32,
	NSNumberLongBitWidth = 64,
	NSNumberLongLongBitWidth = 64,
	NSNumberUnsignedCharBitWidth = 8,
	NSNumberUnsignedShortBitWidth = 16,
	NSNumberUnsignedIntBitWidth = 32,
	NSNumberUnsignedLongBitWidth = 64,
	NSNumberUnsignedLongLongBitWidth = 64
} NSNumberBitWidth;

[[clang::always_inline]]
static inline unsigned long long
_NSNumberUnsignedIntegerValueFromFiniteDouble(double const v, NSNumberBitWidth const bitWidth)
{
	unsigned long long bitRep;
	unsigned long long result;

	__builtin_memcpy_inline(&bitRep, &v, sizeof(bitRep));
	bool isNegative = (bitRep >> 63) != 0;
	unsigned int const exponentBits = (unsigned int)((bitRep >> 52) & 0x7ffULL);

	/* Zeroes, subnormals, and all normal values with a magnitude below one truncate to zero. */
	if (exponentBits == 0)
		return 0;

	int const exponent = (int)exponentBits - 1023;
	if (exponent < 0)
		return 0;

	unsigned long long significand = (bitRep & 0x000fffffffffffffULL) | 0x0010000000000000ULL;
	int shift = exponent - 52;

	if (shift >= bitWidth)
		result = 0;
	else if (shift >= 0) {
		/*
		 * Discard every significand bit that would be shifted beyond the requested result width. Apart from
		 * producing the desired modulo-2^bitWidth result, this ensures the shift cannot overflow its 64-bit
		 * unsigned operand and therefore does not rely on unsigned wrapping.
		 */
		unsigned int const retainedBitWidth = bitWidth - (unsigned int)shift;
		if (retainedBitWidth < 64)
			significand &= (1ULL << retainedBitWidth) - 1ULL;

		result = significand << (unsigned int)shift;
	} else
		result = significand >> (unsigned int)-shift;

	unsigned long long const mask = bitWidth == 64 ? ~0ULL : (1ULL << bitWidth) - 1ULL;
	result &= mask;

	if (isNegative && result != 0)
		result = ((~result & mask) + 1ULL) & mask;

	return result;
}

[[clang::always_inline]]
static inline long long
_NSNumberSignedIntegerValueFromFiniteDouble(double const v, NSNumberBitWidth const bitWidth)
{
	unsigned long long const bits = _NSNumberUnsignedIntegerValueFromFiniteDouble(v, bitWidth);

	if (bitWidth == 64) {
		long long result;
		__builtin_memcpy_inline(&result, &bits, sizeof(result));
		return result;
	}

	if ((bits & (1ULL << (bitWidth - 1))) != 0) {
		unsigned long long const mask = (1ULL << bitWidth) - 1ULL;
		unsigned long long const magnitude = ((~bits) & mask) + 1ULL;
		return -(long long)magnitude;
	}

	return (long long)bits;
}

[[clang::always_inline]]
static inline char
_NSNumberCharValueFromFiniteDouble(double const v)
{
#if defined(__CHAR_UNSIGNED__)
	return (char)_NSNumberUnsignedIntegerValueFromFiniteDouble(v, NSNumberCharBitWidth);
#else
	return (char)_NSNumberSignedIntegerValueFromFiniteDouble(v, NSNumberCharBitWidth);
#endif
}

#define _NSNumberShortValueFromFiniteDouble(v) \
	(short)_NSNumberSignedIntegerValueFromFiniteDouble(v, NSNumberShortBitWidth)

#define _NSNumberIntValueFromFiniteDouble(v) \
	(int)_NSNumberSignedIntegerValueFromFiniteDouble(v, NSNumberIntBitWidth)

#define _NSNumberLongValueFromFiniteDouble(v) \
	(long)_NSNumberSignedIntegerValueFromFiniteDouble(v, NSNumberLongBitWidth)

#define _NSNumberLongLongValueFromFiniteDouble(v) \
	(long long)_NSNumberSignedIntegerValueFromFiniteDouble(v, NSNumberLongLongBitWidth)

#define _NSNumberUnsignedCharValueFromFiniteDouble(v) \
	(unsigned char)_NSNumberUnsignedIntegerValueFromFiniteDouble(v, NSNumberCharBitWidth)

#define _NSNumberUnsignedShortValueFromFiniteDouble(v) \
	(unsigned short)_NSNumberUnsignedIntegerValueFromFiniteDouble(v, NSNumberShortBitWidth)

#define _NSNumberUnsignedIntValueFromFiniteDouble(v) \
	(unsigned int)_NSNumberUnsignedIntegerValueFromFiniteDouble(v, NSNumberIntBitWidth)

#define _NSNumberUnsignedLongValueFromFiniteDouble(v) \
	(unsigned long)_NSNumberUnsignedIntegerValueFromFiniteDouble(v, NSNumberLongBitWidth)

#define _NSNumberUnsignedLongLongValueFromFiniteDouble(v) \
	(unsigned long long)_NSNumberUnsignedIntegerValueFromFiniteDouble(v, NSNumberLongLongBitWidth)

#pragma mark - Methods

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wfloat-equal"

[[clang::always_inline]]
static inline bool
_NSNumberRepresentationIsEqualToNumberRepresentation(NSNumberRepresentation const a, NSNumberRepresentation const b)
{
	if (a.type != b.type)
		return false;

	/* The receiver almost always knows its own type, so we switch on it to let the optimizer go brrr. */
	switch (a.type) {
	case NSNumberRepresentationIntegerValueType:
		return a.isNegative == b.isNegative && a.value.u == b.value.u;
	case NSNumberRepresentationDecimalValueType: /* NSNumber treats NaNs are equal. */
		if (__builtin_isnan(a.value.d) && __builtin_isnan(b.value.d))
			return true;
		return a.value.d == b.value.d;
	}
}

[[clang::always_inline]]
static inline NSComparisonResult
_NumberCompareIntegerAndDecimal(NSNumberRepresentation const a, NSNumberRepresentation const b)
{
	/* Yes, this is a redundant check, but I like playing it safe and the optimizer will make it go away. */
	if (a.type != NSNumberRepresentationIntegerValueType || b.type != NSNumberRepresentationDecimalValueType)
		__builtin_trap();

	double const bvd = b.value.d;
	if (__builtin_isnan(bvd))
		return NSOrderedDescending;

	if (a.isNegative != bvd < 0.0)
		return a.isNegative ? NSOrderedAscending : NSOrderedDescending;

	if (a.isNegative) {
		if (bvd < -0x1p63)
			return NSOrderedDescending;

		unsigned long long const bvdMagnitude = (unsigned long long)-__builtin_trunc(bvd);
		bool const isFractional = bvd < __builtin_trunc(bvd);
		NSComparisonResult cmp = (NSComparisonResult)-(long long)((a.value.u > bvdMagnitude) -
									(a.value.u < bvdMagnitude));

		/* If the second number is fractional, the order is descending. */
		return cmp != NSOrderedSame ? cmp : (NSComparisonResult)isFractional;
	} else {
		if (bvd >= 0x1p64)
			return NSOrderedAscending;

		unsigned long long const bvdMagnitude = (unsigned long long)(__builtin_trunc(bvd));
		bool const isFractional = bvd > __builtin_trunc(bvd);
		NSComparisonResult cmp = (NSComparisonResult)((a.value.u > bvdMagnitude) -
								(a.value.u < bvdMagnitude));

		/* If the second number is fractional, the order is ascending. */
		return cmp != NSOrderedSame ? cmp : (NSComparisonResult)-(long long)isFractional;
	}
}

[[clang::always_inline]]
static inline NSComparisonResult
_NSNumberRepresentationCompare(NSNumberRepresentation const a, NSNumberRepresentation const b)
{
	/* Both are integers. */
	if (a.type == NSNumberRepresentationIntegerValueType && b.type == NSNumberRepresentationIntegerValueType) {
		if (a.isNegative != b.isNegative)
			return a.isNegative ? NSOrderedAscending : NSOrderedDescending;

		/* Signs are the same. */
		if (a.value.u == b.value.u)
			return NSOrderedSame;

		if (a.isNegative == false)
			/* Both positive. */
			return a.value.u < b.value.u ? NSOrderedAscending : NSOrderedDescending;
		else
			/* Both negative. */
			return a.value.u > b.value.u ? NSOrderedAscending : NSOrderedDescending;
	}

	/* Both are decimals. */
	if (a.type == NSNumberRepresentationDecimalValueType && b.type == NSNumberRepresentationDecimalValueType) {
		/* All NaNs compare equal and sort before every other number. */
		if (__builtin_isnan(a.value.d))
			return __builtin_isnan(b.value.d) ? NSOrderedSame : NSOrderedAscending;
		if (__builtin_isnan(b.value.d))
			return NSOrderedDescending;

		return (NSComparisonResult)((a.value.d > b.value.d) - (a.value.d < b.value.d));
	}

	/* Receiver is an integer, other number is a decimal. */
	if (a.type == NSNumberRepresentationIntegerValueType && b.type == NSNumberRepresentationDecimalValueType)
		return _NumberCompareIntegerAndDecimal(a, b);

	/* Receiver is a decimal, other number is an integer. Swap parameters and negate output. */
	if (a.type == NSNumberRepresentationDecimalValueType && b.type == NSNumberRepresentationIntegerValueType)
		return (NSComparisonResult)-(long long)(_NumberCompareIntegerAndDecimal(b, a));

	__builtin_trap();
}

#pragma clang diagnostic pop

NS_ASSUME_NONNULL_END

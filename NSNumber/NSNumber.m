
#import <FoundationPrivate/NSNumber/NSNumber.h>

@implementation NSNumber

unsigned __int128 _NSNumberHashKey;
NSUInteger _NSNaNHash;
NSUInteger _NSNegativeInfinityHash;
NSUInteger _NSPositiveInfinityHash;

Class _NSDoubleNumberClass;
Class _NSNaNDoubleNumberClass;
Class _NSNaNFloatNumberClass;
Class _NSNegativeInfinityDoubleNumberClass;
Class _NSNegativeInfinityFloatNumberClass;
Class _NSNegativeIntegerNumberClass;
Class _NSNumberClass;
Class _NSPositiveInfinityDoubleNumberClass;
Class _NSPositiveInfinityFloatNumberClass;
Class _NSPositiveIntegerNumberClass;
Class _NSTaggedFloatNumberClass;
Class _NSTaggedIntegerNumberClass;

static NSNumberTemplate *_NSNumberTemplateInstance;
NSNaNDoubleNumber *_NSNaNDoubleNumberInstance;
NSNaNFloatNumber *_NSNaNFloatNumberInstance;
NSNegativeInfinityDoubleNumber *_NSNegativeInfinityDoubleNumberInstance;
NSNegativeInfinityFloatNumber *_NSNegativeInfinityFloatNumberInstance;
NSPositiveInfinityDoubleNumber *_NSPositiveInfinityDoubleNumberInstance;
NSPositiveInfinityFloatNumber *_NSPositiveInfinityFloatNumberInstance;
NSTaggedIntegerNumber *_NSBooleanFalseNumberInstance;
NSTaggedIntegerNumber *_NSBooleanTrueNumberInstance;

+ (void)initialize
{
	static NSCallOnceState s = {};

	if (self == [NSNumber class]) {
		NSCallOnce(&s, ^{
			NSRandomBytes(&_NSNumberHashKey, sizeof(_NSNumberHashKey));
			NSRandomBytes(&_NSNaNHash, sizeof(_NSNaNHash));
			NSRandomBytes(&_NSNegativeInfinityHash, sizeof(_NSNegativeInfinityHash));
			NSRandomBytes(&_NSPositiveInfinityHash, sizeof(_NSPositiveInfinityHash));

			_NSDoubleNumberClass = [NSDoubleNumber class];
			_NSNaNDoubleNumberClass = [NSNaNDoubleNumber class];
			_NSNaNFloatNumberClass = [NSNaNFloatNumber class];
			_NSNegativeInfinityDoubleNumberClass = [NSNegativeInfinityDoubleNumber class];
			_NSNegativeInfinityFloatNumberClass = [NSNegativeInfinityFloatNumber class];
			_NSNegativeIntegerNumberClass = [NSNegativeIntegerNumber class];
			_NSNumberClass = [NSNumber class];
			_NSPositiveInfinityDoubleNumberClass = [NSPositiveInfinityDoubleNumber class];
			_NSPositiveInfinityFloatNumberClass = [NSPositiveInfinityFloatNumber class];
			_NSPositiveIntegerNumberClass = [NSPositiveIntegerNumber class];
			_NSTaggedFloatNumberClass = [NSTaggedFloatNumber class];
			_NSTaggedIntegerNumberClass = [NSTaggedIntegerNumber class];

			_NSNumberTemplateInstance = [NSNumberTemplate alloc];
			_NSNaNDoubleNumberInstance = [NSNaNDoubleNumber alloc];
			_NSNaNFloatNumberInstance = [NSNaNFloatNumber alloc];
			_NSNegativeInfinityDoubleNumberInstance = [NSNegativeInfinityDoubleNumber alloc];
			_NSNegativeInfinityFloatNumberInstance = [NSNegativeInfinityFloatNumber alloc];
			_NSPositiveInfinityDoubleNumberInstance = [NSPositiveInfinityDoubleNumber alloc];
			_NSPositiveInfinityFloatNumberInstance = [NSPositiveInfinityFloatNumber alloc];
			_NSBooleanFalseNumberInstance = [NSTaggedIntegerNumber _numberWithBool:false];
			_NSBooleanTrueNumberInstance = [NSTaggedIntegerNumber _numberWithBool:true];
		});
	}
}

+ (instancetype)alloc
{
	if (self == _NSNumberClass)
		return _NSNumberTemplateInstance;

	return class_createInstance(self, 0);
}

+ (instancetype)numberWithChar:(char)value
{
	return (id)[NSTaggedIntegerNumber _numberWithChar:value];
}

+ (instancetype)numberWithUnsignedChar:(unsigned char)value
{
	return (id)[NSTaggedIntegerNumber _numberWithUnsignedChar:value];
}

+ (instancetype)numberWithShort:(short)value
{
	return (id)[NSTaggedIntegerNumber _numberWithShort:value];
}

+ (instancetype)numberWithUnsignedShort:(unsigned short)value
{
	return (id)[NSTaggedIntegerNumber _numberWithUnsignedShort:value];
}

+ (instancetype)numberWithInt:(int)value
{
	return (id)[NSTaggedIntegerNumber _numberWithInt:value];
}

+ (instancetype)numberWithUnsignedInt:(unsigned int)value
{
	return (id)[NSTaggedIntegerNumber _numberWithUnsignedInt:value];
}

+ (instancetype)numberWithLong:(long)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ll = value }, 'l');
}

+ (instancetype)numberWithUnsignedLong:(unsigned long)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ull = value }, 'L');
}

+ (instancetype)numberWithLongLong:(long long)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ll = value }, 'q');
}

+ (instancetype)numberWithUnsignedLongLong:(unsigned long long)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ull = value }, 'Q');
}

+ (instancetype)numberWithInteger:(NSInteger)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ll = value }, 'l');
}

+ (instancetype)numberWithUnsignedInteger:(NSUInteger)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ull = value }, 'L');
}

+ (instancetype)numberWithBool:(bool)value
{
	return value ? _NSBooleanTrueNumberInstance : _NSBooleanFalseNumberInstance;
}

+ (instancetype)numberWithFloat:(float)value
{
	return _NSNumberWithFloat(value);
}

+ (instancetype)numberWithDouble:(double)value
{
	return _NSNumberWithDouble(value);
}

- (instancetype)init
{
	[NSException raise:NSUnavailableMethodUsageException format:@"unavailable method was invoked."];
	return nil;
}

- (instancetype)initWithBytes:(void const *)value objCType:(char const *)type
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithChar:(char)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithUnsignedChar:(unsigned char)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithShort:(short)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithUnsignedShort:(unsigned short)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithInt:(int)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithUnsignedInt:(unsigned int)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithLong:(long)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithUnsignedLong:(unsigned long)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithLongLong:(long long)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithUnsignedLongLong:(unsigned long long)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithInteger:(NSInteger)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithUnsignedInteger:(NSUInteger)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithBool:(bool)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithFloat:(float)value
{
	_NSNumberRejectReinitialization();
}

- (instancetype)initWithDouble:(double)value
{
	_NSNumberRejectReinitialization();
}

- (void *)pointerValue
{
	switch (self.objCType[0]) {
	case 'l': {
		long v;
		[self getValue:&v size:sizeof(v)];
		return (void *)(uintptr_t)v;
	}
	case 'q': {
		long long v;
		[self getValue:&v size:sizeof(v)];
		return (void *)(uintptr_t)v;
	}
	case 'L': {
		unsigned long v;
		[self getValue:&v size:sizeof(v)];
		return (void *)(uintptr_t)v;
	}
	case 'Q': {
		unsigned long long v;
		[self getValue:&v size:sizeof(v)];
		return (void *)(uintptr_t)v;
	}
	default:
		return nullptr;
	}
}

/* Yes, this is ugly, but I say it's preferable to writing even more routines on top of NSNumberRepresentation. */
#define _NSIntegerNumberGettersForType(T, Type) \
	switch (self.objCType[0]) { \
	case 'c': { char v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 's': { short v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'i': { int v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'l': { long v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'q': { long long v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'C': { unsigned char v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'S': { unsigned short v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'I': { unsigned int v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'L': { unsigned long v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'Q': { unsigned long long v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'B': { bool v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'f': { \
		float v; \
		[self getValue:&v size:sizeof(v)]; \
		if (__builtin_isnan(v)) \
			return 0; \
		if (__builtin_isinf(v)) \
			return __builtin_signbit(v) ? NSNumber##Type##Min : NSNumber##Type##Max; \
		return _NSNumber##Type##ValueFromFiniteDouble((double)v); \
	} \
	case 'd': { \
		double v; \
		[self getValue:&v size:sizeof(v)]; \
		if (__builtin_isnan(v)) \
			return 0; \
		if (__builtin_isinf(v)) \
			return __builtin_signbit(v) ? NSNumber##Type##Min : NSNumber##Type##Max; \
		return _NSNumber##Type##ValueFromFiniteDouble(v);\
	} \
	default: [NSException raise:NSInternalInconsistencyException format:@"invalid type encoding."]; \
	} \
	__builtin_trap()

- (char)charValue
{
	_NSIntegerNumberGettersForType(char, Char);
}

- (short)shortValue
{
	_NSIntegerNumberGettersForType(short, Short);
}

- (int)intValue
{
	_NSIntegerNumberGettersForType(int, Int);
}

- (long)longValue
{
	_NSIntegerNumberGettersForType(long, Long);
}

- (long long)longLongValue
{
	_NSIntegerNumberGettersForType(long long, LongLong);
}

- (unsigned char)unsignedCharValue
{
	_NSIntegerNumberGettersForType(unsigned char, UnsignedChar);
}

- (unsigned short)unsignedShortValue
{
	_NSIntegerNumberGettersForType(unsigned short, UnsignedShort);
}

- (unsigned int)unsignedIntValue
{
	_NSIntegerNumberGettersForType(unsigned int, UnsignedInt);
}

- (unsigned long)unsignedLongValue
{
	_NSIntegerNumberGettersForType(unsigned long, UnsignedLong);
}

- (unsigned long long)unsignedLongLongValue
{
	_NSIntegerNumberGettersForType(unsigned long long, UnsignedLongLong);
}

- (NSInteger)integerValue
{
	_NSIntegerNumberGettersForType(long, Long);
}

- (NSUInteger)unsignedIntegerValue
{
	_NSIntegerNumberGettersForType(unsigned long, UnsignedLong);
}

/* TODO: this should be good, no? */
- (bool)boolValue
{
	double v = self.doubleValue;

	if (__builtin_isnan(v))
		return false;
	if (__builtin_isinf(v))
		return __builtin_signbit(v) == 0;

	return (bool)v;
}

#define _NSDecimalNumberGettersForType(T) \
	case 'c': { char v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 's': { short v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'i': { int v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'l': { long v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'q': { long long v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'C': { unsigned char v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'S': { unsigned short v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'I': { unsigned int v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'L': { unsigned long v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'Q': { unsigned long long v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'B': { bool v; [self getValue:&v size:sizeof(v)]; return (T)v; } \
	case 'f': { float v; [self getValue:&v size:sizeof(v)]; return (T)v; }

- (float)floatValue
{
	switch (self.objCType[0]) {
	_NSDecimalNumberGettersForType(float)
	case 'd': {
		/* Casting a double to a float requires special handling. */
		double v;
		[self getValue:&v size:sizeof(v)];
		if (__builtin_isnan(v))
			return __builtin_nanf("");
		if (v > (double)__FLT_MAX__)
			return __builtin_inff();
		if (v < -(double)__FLT_MAX__)
			return -__builtin_inff();

		return (float)v;
	}
	default: [NSException raise:NSInternalInconsistencyException format:@"invalid type encoding."];
	}
	__builtin_trap();
}

- (double)doubleValue
{
	switch (self.objCType[0]) {
	_NSDecimalNumberGettersForType(double)
	case 'd': { double v; [self getValue:&v size:sizeof(v)]; return (double)v; }
	default: [NSException raise:NSInternalInconsistencyException format:@"invalid type encoding."];
	}
	__builtin_trap();
}

- (bool)isEqualToNumber:(NSNumber *)aNumber
{
	_NSRequireNonnil(aNumber);

	return _NSNumberRepresentationIsEqualToNumberRepresentation(
							_NSNumberGetRepresentation(self, self.objCType[0]),
							_NSNumberGetRepresentation(aNumber, aNumber.objCType[0]));
}

- (bool)isEqual:(id)anObject
{
	if ((uintptr_t)self == (uintptr_t)anObject)
		return true;

	if ([(id<NSObject>)anObject isKindOfClass:_NSNumberClass])
		return [self isEqualToNumber:(NSNumber *)anObject];

	return false;
}

- (NSUInteger)hash
{
	NSNumberRepresentation const rep = _NSNumberGetRepresentation(self, self.objCType[0]);
	return NSSipHash((NSUInteger[]){ rep.type, rep.value.u, rep.isNegative },
		sizeof(NSUInteger) * 3, _NSNumberHashKey);
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
	_NSRequireNonnil(otherNumber);

	return _NSNumberRepresentationCompare(_NSNumberGetRepresentation(self, self.objCType[0]),
						_NSNumberGetRepresentation(otherNumber, otherNumber.objCType[0]));
}

@end

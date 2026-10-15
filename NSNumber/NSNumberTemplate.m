
#import <FoundationPrivate/NSNumber/NSNumber.h>

@implementation NSNumberTemplate

- (instancetype)initWithBytes:(void const *)value objCType:(char const *)type
{
	_NSRequireNonnullptr(value);
	_NSRequireNonnullptr(type);

	/* First character must not be zero, second character must be zero. */
	if (type[0] == '\0' || type[1] != '\0')
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"invalid type.");

	switch (type[0]) {
	case 'c':
		return (id)[NSTaggedIntegerNumber _numberWithChar:*(char const *)value];
	case 's':
		return (id)[NSTaggedIntegerNumber _numberWithShort:*(short const *)value];
	case 'i':
		return (id)[NSTaggedIntegerNumber _numberWithInt:*(int const *)value];
	case 'l':
		return _NSLargeNumberWithType((NSLargeCNumber){ .ll = *(long const *)value }, 'l');
	case 'q':
		return _NSLargeNumberWithType((NSLargeCNumber){ .ll = *(long long const *)value }, 'q');
	case 'C':
		return (id)[NSTaggedIntegerNumber _numberWithUnsignedChar:*(unsigned char const *)value];
	case 'S':
		return (id)[NSTaggedIntegerNumber _numberWithUnsignedShort:*(unsigned short const *)value];
	case 'I':
		return (id)[NSTaggedIntegerNumber _numberWithUnsignedInt:*(unsigned int const *)value];
	case 'L':
		return _NSLargeNumberWithType((NSLargeCNumber){ .ull = *(unsigned long const *)value }, 'L');
	case 'Q':
		return _NSLargeNumberWithType((NSLargeCNumber){ .ull = *(unsigned long long const *)value }, 'Q');
	case 'B':
		return *(bool const *)value ? (id)_NSBooleanTrueNumberInstance : (id)_NSBooleanFalseNumberInstance;
	case 'f':
		return _NSNumberWithFloat(*(float const *)value);
	case 'd':
		return _NSNumberWithDouble(*(double const *)value);
	default:
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"invalid type.");
	}
}

- (instancetype)initWithChar:(char)value
{
	return (id)[NSTaggedIntegerNumber _numberWithChar:value];
}

- (instancetype)initWithUnsignedChar:(unsigned char)value
{
	return (id)[NSTaggedIntegerNumber _numberWithUnsignedChar:value];
}

- (instancetype)initWithShort:(short)value
{
	return (id)[NSTaggedIntegerNumber _numberWithShort:value];
}

- (instancetype)initWithUnsignedShort:(unsigned short)value
{
	return (id)[NSTaggedIntegerNumber _numberWithUnsignedShort:value];
}

- (instancetype)initWithInt:(int)value
{
	return (id)[NSTaggedIntegerNumber _numberWithInt:value];
}

- (instancetype)initWithUnsignedInt:(unsigned int)value
{
	return (id)[NSTaggedIntegerNumber _numberWithUnsignedInt:value];
}

- (instancetype)initWithLong:(long)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ll = value }, 'l');
}

- (instancetype)initWithUnsignedLong:(unsigned long)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ull = value }, 'L');
}

- (instancetype)initWithLongLong:(long long)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ll = value }, 'q');
}

- (instancetype)initWithUnsignedLongLong:(unsigned long long)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ull = value }, 'Q');
}

- (instancetype)initWithInteger:(NSInteger)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ll = value }, 'l');
}

- (instancetype)initWithUnsignedInteger:(NSUInteger)value
{
	return _NSLargeNumberWithType((NSLargeCNumber){ .ull = value }, 'L');
}

- (instancetype)initWithBool:(bool)value
{
	return value ? (id)_NSBooleanTrueNumberInstance : (id)_NSBooleanFalseNumberInstance;
}

- (instancetype)initWithFloat:(float)value
{
	return _NSNumberWithFloat(value);
}

- (instancetype)initWithDouble:(double)value
{
	return _NSNumberWithDouble(value);
}

@end

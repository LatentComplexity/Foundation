
#import <FoundationPrivate/NSObject/NSObject.h>
#import <FoundationPrivate/NSObject/NSTypeEncodingString.h>
#import <Foundation/NSMethodSignature.h>

@implementation NSMethodSignature {
	char **_typeComponents;
	NSUInteger _Atomic _hash;
}

@synthesize methodReturnType = _methodReturnType;
@synthesize methodReturnLength = _methodReturnLength;
@synthesize numberOfArguments = _numberOfArguments;
@synthesize frameLength = _frameLength;

static unsigned __int128 _NSMethodSignatureHashKey = 0;

+ (void)initialize
{
	static NSCallOnceState s = {};

	if (self == [NSMethodSignature class])
		NSCallOnce(&s, ^{
			NSRandomBytes(&_NSMethodSignatureHashKey, sizeof(_NSMethodSignatureHashKey));
		});
}

+ (instancetype)signatureWithObjCTypes:(char const *)types
{
	NSMethodSignature *obj;
	NSTypeEncodingStringResult validation;
	char const *p, *q;
	NSUInteger n;
	NSUInteger nBytes;
	NSUInteger frameLength = 0;

	_NSRequireNonnullptr(types);

	if (*types == '\0')
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"'types' was empty.");

	/*
	 * Validate the whole encoding once. Malformed strings and well-formed but un-invocable strings (a union,
	 * bitfield, _Complex, long double, ...) are programmer errors: neither can describe a usable invocation.
	 */
	validation = NSTypeEncodingStringValidate(NSTypeEncodingStringSchemeInvocable, types);

	if (validation.status == NSTypeEncodingStringStatusMalformed ||
	    validation.status == NSTypeEncodingStringStatusUnsupported)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"%@", validation.reason);

	char const *const end = types + strlen(types);

	/*
	 * The string is now known well-formed and invocable. Walk its components to enforce a valid return type,
	 * then a receiver (@) and a selector (:). There must be at least three in all.
	 */
	p = types;
	for (n = 0; p < end; ++n) {
		NSUInteger size;

		q = NSTypeEncodingStringMeasure(p, &size, nullptr, nullptr);

		if (n == 0) {
			char const *b;

			/* The return type cannot be a top-level array. */
			for (b = p; b < q && _NSTypeEncodingIsQualifier(*b); ++b)
				;
			if (b < q && *b == '[')
				_NSRaiseException(MethodContext, NSInvalidArgumentException,
					@"an array cannot be returned by value.");
		} else if (n == 1 && (q - p == 1 && *p == '@') == false)
			_NSRaiseException(MethodContext, NSInvalidArgumentException,
				@"argument 0 of a method signature must be the receiver '@'.");
		else if (n == 2 && (q - p == 1 && *p == ':') == false)
			_NSRaiseException(MethodContext, NSInvalidArgumentException,
				@"argument 1 of a method signature must be the selector ':'.");

		if (n != 0) {
			/*
			 * Individual sizes fit the measurer's bit count, so pointer-width promotion cannot overflow.
			 * But, their sum can, so check it before allocating the signature's component storage.
			 */
			NSUInteger const word = sizeof(void *);
			NSUInteger const argumentSize = *_NSTypeEncodingSkipQualifier(p) == '[' ? word :
				(size + word - 1) & ~(word - 1);
			if (__builtin_add_overflow(frameLength, argumentSize, &frameLength))
				_NSRaiseException(MethodContext, NSInvalidArgumentException,
					@"argument frame is too large in type-encoding string.");
		}

		p = q;
		while (p < end && *p >= '0' && *p <= '9')
			++p;
	}

	/* A method needs a return type, a receiver, and a selector: at least three components. */
	if (n < 3)
		_NSRaiseException(MethodContext, NSInvalidArgumentException,
			@"a method signature must declare a return type, a receiver '@', and a selector ':'.");

	/* Copy each component and measure it; the encoding is well-formed, so the sizing routines are safe. */
	if (__builtin_mul_overflow(n - 1, sizeof(char *), &nBytes))
		_NSRaiseException(MethodContext, NSInvalidArgumentException,
			@"preposterous number of type-encoding string components.");

	obj = class_createInstance(self, 0);
	obj->_numberOfArguments = n - 1;
	obj->_frameLength = frameLength;
	obj->_typeComponents = _NSMalloc(nBytes);

	p = types;

	for (NSUInteger i = 0; i < n; ++i) {
		char *component;
		NSUInteger length;

		q = NSTypeEncodingStringSkip(p);
		length = (NSUInteger)(q - p);

		component = _NSMalloc(length + 1);
		memcpy(component, p, length);
		component[length] = '\0';

		if (i == 0) {
			obj->_methodReturnType = component;
			obj->_methodReturnLength = NSTypeEncodingStringSizeOf(component);
		} else {
			obj->_typeComponents[i - 1] = component;
		}

		p = q;
		while (p < end && *p >= '0' && *p <= '9')
			++p;
	}

	return obj;
}

- (instancetype)init
{
	_NSClusterRejectUnavailableMethodInvocation(MethodContext);
	return nil;
}

/* self.methodReturnType would push us in an autorelease pool unnecessarily. */

- (char const *)getArgumentTypeAtIndex:(NSUInteger)index
{
	if (index >= _numberOfArguments)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"index out of bounds.");

	return _typeComponents[index];
}

- (bool)isOneway
{
	/* `oneway` (V) is a return-type qualifier; scan only the leading qualifier run. */
	for (char const *p = _methodReturnType; *p != '\0' && _NSTypeEncodingIsQualifier(*p); ++p)
		if (*p == 'V')
			return true;

	return false;
}

- (bool)isEqualToMethodSignature:(NSMethodSignature *)aMethodSignature
{
	_NSRequireNonnil(aMethodSignature);

	NSUInteger nArgs;

	if ((uintptr_t)self == (uintptr_t)aMethodSignature)
		return true;

	if ((nArgs = _numberOfArguments) != aMethodSignature->_numberOfArguments)
		return false;

	if (strcmp(_methodReturnType, aMethodSignature->_methodReturnType) != 0)
		return false;

	/* Don't subclass NSMethodSignature. */
	for (NSUInteger i = 0; i < nArgs; ++i)
		if (strcmp(_typeComponents[i], aMethodSignature->_typeComponents[i]) != 0)
			return false;

	return true;
}

- (bool)isEqual:(id)anObject
{
	if ((uintptr_t)self == (uintptr_t)anObject)
		return true;

	if ([(id<NSObject>)anObject isKindOfClass:[NSMethodSignature class]])
		return [self isEqualToMethodSignature:(NSMethodSignature *)anObject];

	return false;
}

- (NSUInteger)hash
{
	NSUInteger h = OSAtomicLoad(&_hash, OSAtomicMemoryOrderRelaxed);

	if (h == 0) {
		NSSipHashContext c;

		NSSipHashContextInit(&c, _NSMethodSignatureHashKey);
		NSSipHashWithContext(&c, _methodReturnType, strlen(_methodReturnType));

		for (NSUInteger i = 0; i < _numberOfArguments; ++i)
			NSSipHashWithContext(&c, _typeComponents[i], strlen(_typeComponents[i]));

		NSSipHashWithContextFinalize(&c, &h);
		OSAtomicStore(&_hash, h, OSAtomicMemoryOrderRelaxed);
	}

	return h;
}

- (void)dealloc
{
	/* Release the return type string. */
	free((void *)(uintptr_t)_methodReturnType);

	/* Release the arguments one by one and their holding array. */
	for (NSUInteger i = 0; i < _numberOfArguments; ++i)
		free(_typeComponents[i]);

	free(_typeComponents);
}

@end

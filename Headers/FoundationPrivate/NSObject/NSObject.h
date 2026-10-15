
#import <Foundation/NSObject.h>

/* Objective-C runtime. */
#include <objc/runtime.h>
#include <objc/objc-exception.h>
#include <objc/objc-arc.h>

/* Exceptions. */
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

/* Supporting routines */
#import <FoundationPrivate/Routines/NSByteOrder.h>
#import <FoundationPrivate/Routines/NSCallOnce.h>
#import <FoundationPrivate/Routines/NSMutex.h>
#import <FoundationPrivate/Routines/NSRandom.h>
#import <FoundationPrivate/Routines/NSSipHash.h>
#import <FoundationPrivate/Routines/OSAtomic.h>

typedef struct NSMethodContext {
	id __unsafe_unretained obj;
	SEL selector;
} NSMethodContext;

#pragma mark - Throwing Facilities

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSRaiseExceptionv(NSMethodContext context, NSExceptionName name, NSString *reasonFmt, __builtin_va_list reasonArgs)
	NS_FORMAT_FUNCTION(3, 0)
{
	NSString *errorString = [[NSString alloc] initWithFormat:reasonFmt arguments:reasonArgs];
	[NSException raise:name format:@"%c[%s %s]: %@", class_isMetaClass(object_getClass(context.obj)) ? '+' : '-',
		object_getClassName(context.obj), sel_getName(context.selector), errorString];

	__builtin_trap();
}

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSRaiseException(NSMethodContext const context, NSExceptionName name, NSString *reasonFmt, ...)
	NS_FORMAT_FUNCTION(3, 4)
{
	__builtin_va_list reasonArgs;
	__builtin_va_start(reasonArgs, reasonFmt);

	NSString *errorString = [[NSString alloc] initWithFormat:reasonFmt arguments:reasonArgs];
	[NSException raise:name format:@"%c[%s %s]: %@", class_isMetaClass(object_getClass(context.obj)) ? '+' : '-',
		object_getClassName(context.obj), sel_getName(context.selector), errorString];

	__builtin_trap();
}

#pragma mark - Raisers

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSRaiseInvalidOption(NSMethodContext const context, char const *const parameterName)
{
	_NSRaiseException(context, NSInvalidArgumentException, @"'%s' was invalid.", parameterName);
}

#pragma mark - Checkers

[[clang::always_inline]]
[[clang::objc_externally_retained]]
static inline void
_NSCRequireNonnil(NSMethodContext const context, id const object, char const *const parameterName)
{
	if (object == nil)
		_NSRaiseException(context, NSInvalidArgumentException, @"'%s' was nil.", parameterName);
}

[[clang::always_inline]]
static inline void
_NSCRequireNonnullptr(NSMethodContext const context, void const *const ptr, char const *const parameterName)
{
	if (ptr == nullptr)
		_NSRaiseException(context, NSInvalidArgumentException, @"'%s' was nullptr.", parameterName);
}

[[clang::always_inline]]
static inline void
_NSCEnumerationOptionsCheck(NSMethodContext const context, NSEnumerationOptions options, char const *const optName)
{
	if (((NSUInteger)options & ~((NSUInteger)NSEnumerationConcurrent | (NSUInteger)NSEnumerationReverse)) != 0)
		_NSRaiseInvalidOption(context, optName);
}

[[clang::always_inline]]
static inline NSUInteger
_NSCRangeMaxCheck(NSMethodContext const context, NSRange const range, char const *const rangeName)
{
	NSUInteger upperBound;

	if (__builtin_add_overflow(range.location, range.length, &upperBound))
		/* TODO: this should probably be an NSInvalidArgumentException, but I'm too lazy to fix tests. */
		_NSRaiseException(context, NSRangeException,
			@"range '%s' with .location = %lu and .length = %lu is unrepresentable.",
			rangeName, range.location, range.length);

	return upperBound;
}

[[clang::always_inline]]
static inline void
_NSCRangeWithinUpperBound(NSMethodContext const context, NSRange const range, NSUInteger const upperBound,
				char const *const rangeName)
{
	if (_NSCRangeMaxCheck(context, range, rangeName) > upperBound)
		_NSRaiseException(context, NSRangeException,
			@"range '%s' with .location = %lu and .length = %lu extends beyond upper bound of %lu.",
			rangeName, range.location, range.length, upperBound);
}

[[clang::always_inline]]
static inline void *
_NSCMalloc(NSMethodContext const ctx, NSUInteger const byteSize)
{
	/* Declare malloc() here to discourage using it by accident within Foundation. */
	void *_Nullable malloc(NSUInteger);

	void *const buffer = malloc(byteSize);
	if (__builtin_expect(!!(buffer == nullptr), 0)) /* Where's my [[unlikely]] at? C23 is lame, boo. */
		_NSRaiseException(ctx, NSMallocException, @"malloc() returned nullptr.");

	return buffer;
}

#pragma mark - Macros

#define MethodContext ((NSMethodContext){.obj = self, .selector = _cmd})

#define _NSRequireNonnil(object) \
	_NSCRequireNonnil(MethodContext, object, #object)

#define _NSRequireNonnullptr(ptr) \
	_NSCRequireNonnullptr(MethodContext, ptr, #ptr)

#define _NSEnumerationOptionsCheck(options) \
	_NSCEnumerationOptionsCheck(MethodContext, options, #options)

#define _NSRangeMaxCheck(range) \
	_NSCRangeMaxCheck(MethodContext, range, #range)

#define _NSRangeWithinUpperBound(range, upperBound) \
	_NSCRangeWithinUpperBound(MethodContext, range, (upperBound), #range)

#define _NSMalloc(byteSize) \
	_NSCMalloc(MethodContext, byteSize)

#pragma mark - Class Cluster Checkers

typedef enum NSSubclassingPolicy : unsigned char {
	_NSSubclassingPermitted = 0,
	_NSSubclassingForbidden = 1
} NSSubclassingPolicy;

typedef struct NSClassSpan {
	Class const *classes;
	NSUInteger count;
} NSClassSpan;

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSClusterRejectReinitialization(NSMethodContext context, Class abstractClass, NSClassSpan privateSubclasses,
					NSSubclassingPolicy subclassingPolicy)
{
	Class const c = object_getClass(context.obj);

	if (c == abstractClass)
		_NSRaiseException(context, NSUninitializedObjectUsageException,
			@"message sent to instance of abstract class.");

	for (NSUInteger i = 0; i < privateSubclasses.count; ++i)
		if (c == privateSubclasses.classes[i])
			_NSRaiseException(context, NSUnavailableMethodUsageException,
				@"reinitialization of initialized object was attempted.");

	if (subclassingPolicy == _NSSubclassingPermitted)
		_NSRaiseException(context, NSUnavailableMethodUsageException,
			@"method must be overridden in subclass.");
	else if (subclassingPolicy == _NSSubclassingForbidden)
		_NSRaiseException(context, NSUnavailableMethodUsageException,
			@"subclassing is not permitted.");
	else
		_NSRaiseException(context, NSInternalInconsistencyException, @"invalid subclassing policy.");

	__builtin_trap();
}

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSClusterRejectInvocation(NSMethodContext context, Class abstractClass, Class templateClass,
				NSSubclassingPolicy subclassingPolicy)
{
	Class const c = object_getClass(context.obj);

	if (c == abstractClass)
		_NSRaiseException(context, NSUninitializedObjectUsageException,
			@"message sent to instance of abstract class.");
	else if (c == templateClass) {
		_NSRaiseException(context, NSUninitializedObjectUsageException,
			@"message sent to instance of uninitialized instance.");
	} else {
		if (subclassingPolicy == _NSSubclassingPermitted)
			_NSRaiseException(context, NSUnavailableMethodUsageException,
				@"method must be overridden in subclass.");
		else if (subclassingPolicy == _NSSubclassingForbidden)
			_NSRaiseException(context, NSUnavailableMethodUsageException,
				@"subclassing is not permitted.");
		else
			_NSRaiseException(context, NSInternalInconsistencyException, @"invalid subclassing policy.");
	}

	__builtin_trap();
}

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSClusterRejectUnavailableMethodInvocation(NSMethodContext context)
{
	_NSRaiseException(context, NSUnavailableMethodUsageException, @"unavailable method was invoked.");
}

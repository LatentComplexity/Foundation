
#import <FoundationPrivate/NSObject/NSObject.h>
#import <Foundation/NSValue.h>

#pragma mark - Classes

@interface NSValueTemplate : NSValue
@end

@interface NSInlineValue : NSValue
+ (instancetype)_valueWithBytes:(void const *)bytes size:(NSUInteger)size objCType:(char const *)type OBJC_DIRECT;
@end

@interface NSVoidPointerValue : NSValue
+ (instancetype)_valueWithPointer:(void const *)pointer OBJC_DIRECT;
@end

@interface NSNullVoidPointerValue : NSValue
@end

typedef struct [[gnu::may_alias]] NSInlineValueLayout {
	void const *const isa;
	char const *const bytes;
	NSUInteger const size;
	char const *const objCType;
	NSUInteger _Atomic const hash;
} NSInlineValueLayout;

typedef struct [[gnu::may_alias]] NSVoidPointerValueLayout {
	void const *const isa;
	void const *const pointerValue;
} NSVoidPointerValueLayout;

#pragma mark - Globals

[[gnu::visibility("hidden")]]
extern unsigned __int128 _NSValueHashKey;

[[gnu::visibility("hidden")]]
extern NSUInteger _NSNullVoidPointerValueHash;

[[gnu::visibility("hidden")]]
extern Class _NSValueClass;

[[gnu::visibility("hidden")]]
extern Class _NSValueTemplateClass;

[[gnu::visibility("hidden")]]
extern Class _NSInlineValueClass;

[[gnu::visibility("hidden")]]
extern Class _NSVoidPointerValueClass;

[[gnu::visibility("hidden")]]
extern Class _NSNullVoidPointerValueClass;

[[gnu::visibility("hidden")]]
extern NSNullVoidPointerValue *_NSNullVoidPointerValueInstance;

[[clang::always_inline]]
static inline void
_NSCValueRequireSizeMatchingType(NSMethodContext const context, NSUInteger inputSize, NSUInteger valueSize,
					char const *objCType)
{
	if (inputSize != valueSize)
		_NSRaiseException(context, NSInvalidArgumentException,
			@"expected size of %lu bytes to match type encoding '%s', received size of %lu bytes.",
			valueSize, objCType, inputSize);
}

#define _NSValueRequireSizeMatchingType(inputSize, valueSize, objCType) \
	_NSCValueRequireSizeMatchingType(MethodContext, (inputSize), (valueSize), (objCType))

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCValueRejectReinitialization(NSMethodContext const context)
{
	_NSClusterRejectReinitialization(context, _NSValueClass,
		(NSClassSpan) {
			.classes = (Class[]){ _NSInlineValueClass, _NSVoidPointerValueClass,
						_NSNullVoidPointerValueClass },
			.count = 3
		}, _NSSubclassingPermitted);
}

#define _NSValueRejectReinitialization() \
	_NSCValueRejectReinitialization(MethodContext)

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSCValueRejectInvocation(NSMethodContext const context)
{
	_NSClusterRejectInvocation(context, _NSValueClass, _NSValueTemplateClass, _NSSubclassingPermitted);
}

#define _NSValueRejectInvocation() \
	_NSCValueRejectInvocation(MethodContext)

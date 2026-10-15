
#import <FoundationPrivate/NSObject/NSObject.h>
#import <Foundation/NSString.h>

/* Private subclasses. */
#import <FoundationPrivate/NSString/NSUTF8Helpers.h>
#import <FoundationPrivate/NSString/NSStringTemplate.h>
#import <FoundationPrivate/NSString/NSTaggedConstantString.h>
#import <FoundationPrivate/NSString/NSConstantString.h>
#import <FoundationPrivate/NSString/NSASCIIString.h>
#import <FoundationPrivate/NSString/NSUTF16String.h>

/* Internal dependencies. */
#import <Foundation/NSData.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Constants

[[gnu::visibility("hidden")]]
extern unsigned __int128 _NSStringHashKey;

[[gnu::visibility("hidden")]]
extern Class _NSStringClass;

[[gnu::visibility("hidden")]]
extern Class _NSStringTemplateClass;

[[gnu::visibility("hidden")]]
extern Class _NSTaggedConstantStringClass;

[[gnu::visibility("hidden")]]
extern Class _NSConstantStringClass;

[[gnu::visibility("hidden")]]
extern Class _NSASCIIStringClass;

[[gnu::visibility("hidden")]]
extern Class _NSUTF16StringClass;

#pragma mark - Class Cluster Checkers

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSStringRejectReinitialization(NSMethodContext const ctx)
{
	_NSClusterRejectReinitialization(ctx, _NSStringClass,
		(NSClassSpan) {
			.classes = (Class[]){ _NSTaggedConstantStringClass, _NSConstantStringClass,
						_NSASCIIStringClass, _NSUTF16StringClass },
			.count = 4
		}, _NSSubclassingPermitted);
}

[[noreturn]]
[[clang::always_inline]]
static inline void
_NSStringRejectInvocation(NSMethodContext const ctx)
{
	_NSClusterRejectInvocation(ctx, _NSStringClass, _NSStringTemplateClass, _NSSubclassingPermitted);
}

NS_ASSUME_NONNULL_END

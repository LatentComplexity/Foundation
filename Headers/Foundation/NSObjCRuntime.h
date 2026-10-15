
#include <objc/runtime.h>
#include <objc/objc-arc.h>
#include <limits.h>

typedef long NSInteger;
typedef unsigned long NSUInteger;

#ifndef _PTRDIFF_T_DEFINED_
#define _PTRDIFF_T_DEFINED_
typedef long ptrdiff_t;
#endif

#ifndef _SIZE_T_DEFINED_
#define _SIZE_T_DEFINED_
typedef unsigned long size_t;
#endif

#ifndef _INTPTR_T_DEFINED_
#define _INTPTR_T_DEFINED_
typedef long intptr_t;
#endif

#ifndef _UINTPTR_T_DEFINED_
#define _UINTPTR_T_DEFINED_
typedef unsigned long uintptr_t;
#endif

#define NSIntegerMax	9223372036854775807LL
#define NSIntegerMin	(-9223372036854775807LL - 1LL)
#define NSUIntegerMax	18446744073709551615ULL
#define NSUIntegerMin	0ULL
#define NSNotFound	NSIntegerMax

#ifndef __unused
#define __unused __attribute__((unused))
#endif

#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#endif

#ifndef NS_ASSUME_NONNULL_END
#define NS_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")
#endif

#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER [[clang::objc_designated_initializer]]
#endif

#ifndef NS_RETURNS_INNER_POINTER
#define NS_RETURNS_INNER_POINTER [[clang::objc_returns_inner_pointer]]
#endif

#ifndef NS_ROOT_CLASS
#define NS_ROOT_CLASS [[clang::objc_root_class]]
#endif

#ifndef NS_NOESCAPE
#define NS_NOESCAPE __attribute__((noescape))
#endif

#ifndef NS_NO_TAIL_CALL
#define NS_NO_TAIL_CALL __attribute__((not_tail_called))
#endif

#ifndef NS_FORMAT_FUNCTION
#define NS_FORMAT_FUNCTION(f, a) __attribute__((format(__NSString__, f, a)))
#endif

#ifndef NS_FORMAT_ARGUMENT
#define NS_FORMAT_ARGUMENT(a) __attribute__((format_arg(a)))
#endif

#ifndef NS_UNAVAILABLE
#define NS_UNAVAILABLE [[clang::unavailable]]
#endif

#ifndef NS_REQUIRES_NIL_TERMINATION
#define NS_REQUIRES_NIL_TERMINATION __attribute__((sentinel(0, 1)))
#endif

#ifndef NS_NORETURN
#define NS_NORETURN __attribute__((noreturn))
#endif

#ifndef OBJC_DIRECT
#define OBJC_DIRECT [[clang::objc_direct]]
#endif

#ifndef OBJC_RETURNS_RETAINED
#define OBJC_RETURNS_RETAINED [[clang::ns_returns_retained]]
#endif

#ifndef NS_CLOSED_ENUM_ATTR
#define NS_CLOSED_ENUM_ATTR [[clang::enum_extensibility(closed)]]
#endif

#ifndef NS_OPTIONS_ENUM_ATTR
#define NS_OPTIONS_ENUM_ATTR __attribute__((flag_enum))
#endif

#ifndef MIN
#define MIN(a, b) (__builtin_elementwise_min(a, b))
#endif

#ifndef MAX
#define MAX(a, b) (__builtin_elementwise_max(a, b))
#endif

#ifndef ABS
#define ABS(a) (__builtin_elementwise_abs(a))
#endif

#ifndef unreachable
#define unreachable() __builtin_unreachable()
#endif

NS_ASSUME_NONNULL_BEGIN

@class NSString;

typedef enum NS_CLOSED_ENUM_ATTR NSComparisonResult : NSInteger {
	NSOrderedAscending = -1L,
	NSOrderedSame = 0L,
	NSOrderedDescending = 1L
} NSComparisonResult;

typedef enum NS_OPTIONS_ENUM_ATTR NSEnumerationOptions : NSUInteger {
	NSEnumerationNoOptions = 0,
	NSEnumerationConcurrent = 1UL << 0,
	NSEnumerationReverse = 1UL << 1
} NSEnumerationOptions;

typedef enum NS_OPTIONS_ENUM_ATTR NSSortOptions : NSUInteger {
	NSSortConcurrent = 1UL << 0,
	NSSortStable = 1UL << 1
} NSSortOptions;

typedef NSComparisonResult (^NSComparator)(id obj1, id obj2);
typedef NSString *NSExceptionName;

NSString *
NSStringFromClass(Class);

Class _Nullable
NSClassFromString(NSString *);

NSString *
NSStringFromSelector(SEL);

SEL
NSSelectorFromString(NSString *);

NSString *
NSStringFromProtocol(Protocol *);

Protocol *_Nullable
NSProtocolFromString(NSString *);

char const *
NSGetSizeAndAlignment(char const *, NSUInteger *_Nullable, NSUInteger *_Nullable);

void
NSLog(NSString *, ...) NS_FORMAT_FUNCTION(1, 2) NS_NO_TAIL_CALL;

void
NSLogv(NSString *, __builtin_va_list) NS_FORMAT_FUNCTION(1, 0) NS_NO_TAIL_CALL;

/* Clang assumes the existence of the mem* family at a bare minimum. These should probably be moved internally. */
void *memcpy(void *restrict, void const *restrict, NSUInteger);
void *memmove(void *, void const *, NSUInteger);
void *memset(void *, int, NSUInteger);
int memcmp(void const *, void const *, NSUInteger n);

NSUInteger strlen(char const *);
int strcmp(char const *, char const *);
char *strdup(char const *);
char *strchr(char const *, int);
void *memchr(void const *, int, NSUInteger);
void *memrchr(void const *, int, NSUInteger);
void *memmem(void const *, NSUInteger, void const *, NSUInteger);

void qsort(void *, NSUInteger, NSUInteger, int (*)(void const *, void const *));

void *_Nullable realloc(void *_Nullable, NSUInteger);
void *_Nullable calloc(NSUInteger, NSUInteger);
void free(void *);

int dprintf(int, char const *restrict, ...);
int asprintf(char *_Nullable *_Nonnull restrict, const char *_Nonnull restrict, ...);
NSInteger write(int, void const *, NSUInteger);

void abort(void) __attribute__((noreturn));

NS_ASSUME_NONNULL_END

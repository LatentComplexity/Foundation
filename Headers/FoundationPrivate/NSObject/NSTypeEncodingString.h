
#import <Foundation/NSObjCRuntime.h>

NS_ASSUME_NONNULL_BEGIN

@class NSString;

/*
 * Describes which lexicon a type-encoding string is held to.
 *
 * A "Storable" lexicon is the whole Objective-C type-encoding lexicon. Unions, bitfields, _Complex, long double, and
 * __int128 are all acceptable. Lexically broken strings and unrepresentable layouts fail. NSValue and misc. use
 * this mode.
 *
 * A "Invocable" lexicon is the strict subset that NSMethodSignature and NSInvocation can actually call. Everything
 * "Storable" accepts that is not in that subset is reported as "Unsupported" (valid, but not invocable.)
 *
 * Neither scheme accepts the extended/property forms that @encode() and method type encodings never produce: quoted
 * class names (@"Class"), protocol qualifiers (@?<Proto>), and struct/union field names are all rejected as malformed.
 */
typedef enum NSTypeEncodingStringScheme : unsigned char {
	NSTypeEncodingStringSchemeStorable = 0,
	NSTypeEncodingStringSchemeInvocable
} NSTypeEncodingStringScheme;

/*
 * The outcome of validating a whole type-encoding string.
 *
 * OK: well-formed and permitted under the requested scheme.
 * Malformed: invalid syntax or an unrepresentable count, size, or layout.
 * Unsupported: lexically valid, but outside the requested scheme's permitted subset.
 */
typedef enum NSTypeEncodingStringStatus : unsigned char {
	NSTypeEncodingStringStatusOK = 0,
	NSTypeEncodingStringStatusMalformed,
	NSTypeEncodingStringStatusUnsupported
} NSTypeEncodingStringStatus;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpadded"

/*
 * The reason is nil when status is OK. Otherwise, it contains a message body with no caller prefix. Callers prepend
 * their own naming context. It's easier to ignore the warning entirely than to add padding and fill in an extra field
 * to all of two spots returning a result literal.
 */
typedef struct NSTypeEncodingStringResult {
	NSTypeEncodingStringStatus status;
	NSString *_Nullable reason;
} NSTypeEncodingStringResult;

#pragma clang diagnostic pop

/* Type qualifiers: const, in, inout, out, bycopy, byref, oneway, atomic. */
[[clang::always_inline]]
static inline bool
_NSTypeEncodingIsQualifier(char c)
{
	return c == 'r' || c == 'n' || c == 'N' || c == 'o' || c == 'O' || c == 'R' || c == 'V' || c == 'A';
}

[[clang::always_inline]]
static inline char const *
_NSTypeEncodingSkipQualifier(char const *p)
{
	while (*p == 'r' || *p == 'n' || *p == 'N' || *p == 'o' || *p == 'O' || *p == 'R' || *p == 'V' || *p == 'A')
		++p;

	return p;
}

/*
 * Validate an entire type-encoding string. One or more concatenated types, each optionally followed by a decimal frame
 * offset. Reports the first error encountered. The type string must be a nonnull, non-empty, null-terminated C
 * string. Every component and nested type must have a size in bits and a leaf count representable by NSUInteger,
 * including intermediate layout calculations. This bounds subsequent byte-size promotion as well.
 */
NSTypeEncodingStringResult
NSTypeEncodingStringValidate(NSTypeEncodingStringScheme scheme, char const *types);

/*
 * Measure exactly one pre-validated type, writing its size and alignment in bytes as taken up on LP64 platforms, plus
 * its leaf count, for whichever of the three out-pointers are nonnull. A leaf is a terminal member: a pointer counts
 * as one and its pointee is not descended into, structs sum their fields, unions take the max of theirs, and arrays
 * multiply. Behaviour is undefined if the type in question was not validated by NSTypeEncodingStringValidate() under
 * the "Storable" or "Invocable" scheme; ditto for every other wrapper method below it.
 */
char const *
NSTypeEncodingStringMeasure(char const *type, NSUInteger *_Nullable size, NSUInteger *_Nullable alignment,
	NSUInteger *_Nullable leafCount);

/* Size of one pre-validated type, in bytes. Equivalent to objc_sizeof_type(). */
[[clang::always_inline]]
static inline NSUInteger
NSTypeEncodingStringSizeOf(char const *type)
{
	NSUInteger size;

	NSTypeEncodingStringMeasure(type, &size, nullptr, nullptr);
	return size;
}

/* Alignment of one pre-validated type, in bytes (never zero). Equivalent to objc_alignof_type(). */
[[clang::always_inline]]
static inline NSUInteger
NSTypeEncodingStringAlignOf(char const *type)
{
	NSUInteger alignment;

	NSTypeEncodingStringMeasure(type, nullptr, &alignment, nullptr);
	return alignment;
}

/*
 * Number of leaves (terminal members) in one pre-validated type. A lone pointer-sized scalar, object, or wrapped
 * pointer is one leaf; a struct of two ints or an array of two elements is two. See NSTypeEncodingStringMeasure().
 */
[[clang::always_inline]]
static inline NSUInteger
NSTypeEncodingStringLeafCountOf(char const *type)
{
	NSUInteger leafCount;

	NSTypeEncodingStringMeasure(type, nullptr, nullptr, &leafCount);
	return leafCount;
}

/* The position just past one pre-validated type. Equivalent to objc_skip_typespec(). */
[[clang::always_inline]]
static inline char const *
NSTypeEncodingStringSkip(char const *type)
{
	return NSTypeEncodingStringMeasure(type, nullptr, nullptr, nullptr);
}

/*
 * Size of one pre-validated type rounded up to the argument-frame word (pointer width). Equivalent to
 * objc_promoted_size().
 */
[[clang::always_inline]]
static inline NSUInteger
NSTypeEncodingStringPromotedSizeOf(char const *type)
{
	NSUInteger size = NSTypeEncodingStringSizeOf(type);
	NSUInteger word = sizeof(void *);
	NSUInteger remainder = size % word;

	if (remainder != 0)
		size += word - remainder;

	return size;
}

NS_ASSUME_NONNULL_END

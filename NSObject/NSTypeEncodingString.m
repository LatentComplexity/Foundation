
/*
 *  - NSTypeEncodingStringValidate walks a whole string carefully, classifying any failure as Malformed (not a valid
 *    encoding at all) or, under the Invocable scheme, Unsupported (valid, but outside the subset that
 *    NSMethodSignature/NSInvocation can call), checks that its layout is representable, and builds a message to
 *    raise upon failure.
 *  - NSTypeEncodingStringMeasure trusts its input (one pre-validated type at a time) and computes size and
 *    alignment in a single recursive pass. Validation shares this measurement pass to check layout arithmetic.
 *
 * Both parsers accept only the "simple" lexicon that @encode() and method type encodings produce: bare '@'/'@?'
 * objects, with no @"Class"/@?<Proto> extended forms and no struct/union field names. Those belong to the property
 * type-encoding lexicon (and the runtime's extended method types table), but not to @encode() or a method signature.
 * The validator rejects them; the measurer, which trusts one pre-validated type at a time, never sees them. Sizes
 * and alignments are for LP64.
 */

#import <FoundationPrivate/NSObject/NSTypeEncodingString.h>
#import <Foundation/NSString.h>

#pragma mark - Misc

enum : NSUInteger {
	MaxRecursionDepth = 128
};

[[clang::always_inline]]
static inline bool
_NSTypeEncodingIsDigit(char c)
{
	return c >= '0' && c <= '9';
}

/* The scalar types that may follow a _Complex 'j'. */
[[clang::always_inline]]
static inline bool
_NSTypeEncodingIsComplexScalar(char c)
{
	switch (c) {
	case 'c': case 'C': case 's': case 'S': case 'i': case 'I':
	case 'l': case 'L': case 'q': case 'Q': case 'f': case 'd': case 'D':
		return true;
	}

	return false;
}

/* Round the value up to the next multiple of the alignment; both in bits. */
[[clang::always_inline]]
static inline bool
_NSTypeEncodingRoundUp(NSUInteger value, NSUInteger alignment, NSUInteger *result)
{
	NSUInteger remainder;

	if (alignment != 0 && (remainder = value % alignment) != 0)
		return __builtin_add_overflow(value, alignment - remainder, result) == false;

	*result = value;
	return true;
}

/*
 * Consume a run of decimal digits at *pp (NUL-bounded), advancing *pp past the whole run. Returns false on overflow;
 * the run is still fully consumed, but *out is then meaningless. The validator calls this directly and turns overflow
 * into a failure; the measurer reaches it through _NSTypeEncodingScanDigitsTrusted() below, where overflow is
 * impossible on pre-validated input.
 */
[[clang::always_inline]]
static inline bool
_NSTypeEncodingScanDigits(char const **pp, NSUInteger *out)
{
	NSUInteger value = 0;
	char const *p = *pp;
	bool ok = true;

	while (_NSTypeEncodingIsDigit(*p)) {
		NSUInteger scaled;

		if (__builtin_mul_overflow(value, (NSUInteger)10, &scaled) ||
		    __builtin_add_overflow(scaled, (NSUInteger)(*p - '0'), &value))
			ok = false;

		++p;
	}

	*pp = p;
	*out = value;
	return ok;
}

/* As above, on pre-validated input where overflow cannot occur; trap if it somehow does. */
[[clang::always_inline]]
static inline NSUInteger
_NSTypeEncodingScanDigitsTrusted(char const **pp)
{
	NSUInteger value;

	if (_NSTypeEncodingScanDigits(pp, &value) == false)
		__builtin_trap();

	return value;
}

#pragma mark - Measure

static char const *_NSTypeEncodingMeasure(char const *type, NSUInteger *sizeBits, NSUInteger *alignBits,
	NSUInteger *leaves);

/* Size and alignment, in bits, of a scalar leaf. Returns false if c is not one. */
[[clang::always_inline]]
static inline bool
_NSTypeEncodingScalarBits(char c, NSUInteger *sizeBits, NSUInteger *alignBits)
{
	NSUInteger bytes;

	switch (c) {
	/* char, unsigned char, _Bool */
	case 'c':
	case 'C':
	case 'B':
		bytes = 1;
		break;

	/* short */
	case 's':
	case 'S':
		bytes = 2;
		break;

	/* int, float */
	case 'i':
	case 'I':
	case 'f':
		bytes = 4;
		break;

	/* long, long long, double */
	case 'l':
	case 'L':
	case 'q':
	case 'Q':
	case 'd':
		bytes = 8;
		break;

	/*
	 * (NOTE: long double is only (padded to, in the case of amd64) 16 bytes on UNIX platforms! macOS and Windows
	 * define long double as 8 bytes.
	 */
	/* long double */
	case 'D':
		bytes = 16;
		break;

	/* __int128 */
	case 't':
	case 'T':
		bytes = 16;
		break;

	/* char *, Class, SEL */
	case '*':
	case '#':
	case ':':
		bytes = 8;
		break;

	default:
		return false;
	}

	/* All of these alias their natural alignment to their size on LP64. */
	*sizeBits = bytes * 8;
	*alignBits = bytes * 8;
	return true;
}

/* Array: [<count><element>]. */
static char const *
_NSTypeEncodingMeasureArray(char const *type, NSUInteger *sizeBits, NSUInteger *alignBits, NSUInteger *leaves)
{
	NSUInteger count;
	NSUInteger elementBits, elementLeaves, total, totalLeaves;

	++type; /* past '[' */
	count = _NSTypeEncodingScanDigitsTrusted(&type);
	if ((type = _NSTypeEncodingMeasure(type, &elementBits, alignBits, &elementLeaves)) == nullptr)
		return nullptr;

	if (*type == ']')
		++type;

	if (__builtin_mul_overflow(elementBits, count, &total) ||
	    __builtin_mul_overflow(elementLeaves, count, &totalLeaves))
		return nullptr;

	*sizeBits = total;
	*leaves = totalLeaves;
	return type;
}

/* Struct {tag=fields} or union (tag=fields). */
static char const *
_NSTypeEncodingMeasureAggregate(char const *type, NSUInteger *sizeBits, NSUInteger *alignBits, NSUInteger *leaves,
	char close, bool isUnion)
{
	NSUInteger runBits = 0;
	NSUInteger runLeaves = 0;
	NSUInteger maxAlign = 8; /* At least one byte, even for an empty aggregate. */

	/* Go past '{' or '(' */
	++type;

	/* Skip the tag. */
	while (*type != '\0' && *type != '=' && *type != close)
		++type;

	if (*type == '=')
		++type;
	/* else: opaque/incomplete aggregate ({Foo} / {?}); the loop below sees the close at once. */

	while (*type != '\0' && *type != close) {
		NSUInteger fieldBits, fieldAlign, fieldLeaves;

		/* Bitfield: packs in bits, no alignment rounding; counts as a single leaf. */
		if (*type == 'b') {
			NSUInteger fieldWidth;

			++type;
			fieldWidth = _NSTypeEncodingScanDigitsTrusted(&type);

			if (isUnion) {
				if (fieldWidth > runBits)
					runBits = fieldWidth;
				if (runLeaves < 1)
					runLeaves = 1;
			} else {
				if (__builtin_add_overflow(runBits, fieldWidth, &runBits) ||
				    __builtin_add_overflow(runLeaves, (NSUInteger)1, &runLeaves))
					return nullptr;
			}

			continue;
		}

		if ((type = _NSTypeEncodingMeasure(type, &fieldBits, &fieldAlign, &fieldLeaves)) == nullptr)
			return nullptr;

		if (fieldAlign > maxAlign)
			maxAlign = fieldAlign;

		if (isUnion) {
			if (fieldBits > runBits)
				runBits = fieldBits;
			/* A union occupies one slot: its leaf count is that of its most complex member. */
			if (fieldLeaves > runLeaves)
				runLeaves = fieldLeaves;
		} else {
			if (_NSTypeEncodingRoundUp(runBits, fieldAlign, &runBits) == false ||
			    __builtin_add_overflow(runBits, fieldBits, &runBits) ||
			    __builtin_add_overflow(runLeaves, fieldLeaves, &runLeaves))
				return nullptr;
		}
	}

	if (*type == close)
		++type;

	if (_NSTypeEncodingRoundUp(runBits, maxAlign, sizeBits) == false)
		return nullptr;
	*alignBits = maxAlign;
	*leaves = runLeaves;
	return type;
}

static char const *
_NSTypeEncodingMeasure(char const *type, NSUInteger *sizeBits, NSUInteger *alignBits, NSUInteger *leaves)
{
	NSUInteger leafSize, leafAlign;

	while (_NSTypeEncodingIsQualifier(*type))
		++type;

	if (_NSTypeEncodingScalarBits(*type, &leafSize, &leafAlign)) {
		*sizeBits = leafSize;
		*alignBits = leafAlign;
		*leaves = 1;
		return type + 1;
	}

	switch (*type) {
	case 'v': /* void */
	case '?': /* Unknown/function-pointer target. */
		*sizeBits = 0;
		*alignBits = 8; /* never report alignment of 0. */
		*leaves = 1;
		return type + 1;

	/* id (@) or a block (@?). */
	case '@':
		*sizeBits = 64;
		*alignBits = 64;
		*leaves = 1;
		return (type[1] == '?') ? type + 2 : type + 1;

	/* Pointer(s) to one type. */
	case '^': {
		NSUInteger ignoredSize, ignoredAlign, ignoredLeaves;

		while (*type == '^')
			++type;

		/* Skip the pointee; a pointer is a single leaf regardless of what it addresses. */
		if ((type = _NSTypeEncodingMeasure(type, &ignoredSize, &ignoredAlign, &ignoredLeaves)) == nullptr)
			return nullptr;
		*sizeBits = 64;
		*alignBits = 64;
		*leaves = 1;
		return type;
	}

	/* _Complex <scalar>: twice the scalar, scalar's align. */
	case 'j': {
		NSUInteger elementSize, elementAlign;

		++type;
		if (_NSTypeEncodingScalarBits(*type, &elementSize, &elementAlign) == false) {
			*sizeBits = 0;
			*alignBits = 8;
			*leaves = 1;
			return type;
		}

		*sizeBits = elementSize * 2;
		*alignBits = elementAlign;
		*leaves = 1;
		return type + 1;
	}

	case '[':
		return _NSTypeEncodingMeasureArray(type, sizeBits, alignBits, leaves);

	case '{':
		return _NSTypeEncodingMeasureAggregate(type, sizeBits, alignBits, leaves, '}', false);

	case '(':
		return _NSTypeEncodingMeasureAggregate(type, sizeBits, alignBits, leaves, ')', true);

	/* Lone bitfield: round its width up to whole bytes. */
	case 'b': {
		NSUInteger width;

		++type;
		width = _NSTypeEncodingScanDigitsTrusted(&type);
		if (_NSTypeEncodingRoundUp(width, 8, sizeBits) == false)
			return nullptr;
		*alignBits = 8;
		*leaves = 1;
		return type;
	}
	}

	/* Unreachable for pre-validated input. */
	__builtin_trap();
}

char const *
NSTypeEncodingStringMeasure(char const *type, NSUInteger *size, NSUInteger *alignment, NSUInteger *leafCount)
{
	NSUInteger sizeBits = 0, alignBits = 8, leaves = 0;

	char const *end = _NSTypeEncodingMeasure(type, &sizeBits, &alignBits, &leaves);
	/* A null result indicates layout overflow, which validation must have rejected. */
	if (end == nullptr)
		__builtin_trap();

	if (size != nullptr)
		*size = sizeBits / 8;

	if (alignment != nullptr)
		*alignment = alignBits / 8;

	if (leafCount != nullptr)
		*leafCount = leaves;

	return end;
}

#pragma mark - Validation

/*
 * `errKind` discriminates the failure:
 * 'c' for invalid character or truncation, 'u' for unsupported construct, ']' for stray closing bracket, '{', '[',
 * and '(' for missing closing for struct/array/union, 'd' for hitting the nesting limit, 'b' for a bitfield not
 * followed by a width digit, and 'A'/'W'/'F' for an array count / bitfield width / frame offset too large to
 * represent, and 'S' for an unrepresentable layout or leaf count.
 */
typedef struct ValidateContext {
	char const *end;
	char const *errAt;
	char const *topAggregate; /* Outermost open aggregate's opener, or null at top level. */
	NSTypeEncodingStringScheme scheme;
	NSTypeEncodingStringStatus status;
	char errKind;
	char padding[5];
} ValidateContext;

static void
_NSTypeEncodingFail(ValidateContext *ctx, char const *at, char kind)
{
	/* Keep the first failure. */
	if (ctx->status != NSTypeEncodingStringStatusOK)
		return;

	ctx->errAt = at;
	ctx->errKind = kind;
	ctx->status = (kind == 'u') ? NSTypeEncodingStringStatusUnsupported : NSTypeEncodingStringStatusMalformed;
}

static char const *_NSTypeEncodingParse(ValidateContext *ctx, char const *p, NSUInteger depth);

/* Array: [<count><element>]. */
static char const *
_NSTypeEncodingParseArray(ValidateContext *ctx, char const *p, NSUInteger depth)
{
	char const *const start = p;
	bool const outermost = depth == 0;
	[[maybe_unused]] NSUInteger count;

	if (outermost)
		ctx->topAggregate = p;

	++p; /* past '[' */
	if (_NSTypeEncodingScanDigits(&p, &count) == false) {
		_NSTypeEncodingFail(ctx, start, 'A');
		return nullptr;
	}

	/* Truncated before the element: report the missing bracket, not the element's end-of-string. */
	if (p >= ctx->end) {
		_NSTypeEncodingFail(ctx, start, '[');
		return nullptr;
	}

	if ((p = _NSTypeEncodingParse(ctx, p, depth + 1)) == nullptr)
		return nullptr;

	if (p >= ctx->end || *p != ']') {
		_NSTypeEncodingFail(ctx, start, '[');
		return nullptr;
	}

	++p;
	if (outermost)
		ctx->topAggregate = nullptr;

	return p;
}

/* Struct {tag=fields} or union (tag=fields); open is the bracket recorded for a missing-close failure. */
static char const *
_NSTypeEncodingParseAggregate(ValidateContext *ctx, char const *p, NSUInteger depth, char open, char close)
{
	char const *const start = p;
	bool const outermost = depth == 0;

	if (outermost)
		ctx->topAggregate = p;

	for (++p; p < ctx->end && *p != '=' && *p != close; ++p)
		;

	if (p >= ctx->end) {
		_NSTypeEncodingFail(ctx, start, open);
		return nullptr;
	}

	/* Opaque/incomplete aggregate. */
	if (*p == close) {
		++p;
		if (outermost)
			ctx->topAggregate = nullptr;

		return p;
	}

	for (++p; p < ctx->end && *p != close;) {
		/* Parse the actual type. */
		if ((p = _NSTypeEncodingParse(ctx, p, depth + 1)) == nullptr)
			return nullptr;
	}

	if (p >= ctx->end || *p != close) {
		_NSTypeEncodingFail(ctx, start, open);
		return nullptr;
	}

	++p;
	if (outermost)
		ctx->topAggregate = nullptr;

	return p;
}

/* Bitfield: b<bits>. Only reached under the Storable scheme. */
static char const *
_NSTypeEncodingParseBitfield(ValidateContext *ctx, char const *p)
{
	char const *const start = p; /* the 'b' */
	[[maybe_unused]] NSUInteger width;

	++p;
	/* 'b' must be followed immediately by a width digit. */
	if (p >= ctx->end || _NSTypeEncodingIsDigit(*p) == false) {
		_NSTypeEncodingFail(ctx, p, 'b');
		return nullptr;
	}

	if (_NSTypeEncodingScanDigits(&p, &width) == false) {
		_NSTypeEncodingFail(ctx, start, 'W');
		return nullptr;
	}

	return p;
}

/* Parse exactly one type; returns the position just past it, or null after stamping the failure into `ctx`. */
static char const *
_NSTypeEncodingParse(ValidateContext *ctx, char const *p, NSUInteger depth)
{
	bool const invocable = ctx->scheme == NSTypeEncodingStringSchemeInvocable;

	/* Fail if we exceeded our recursion limit or have walked off the end. */
	if (depth > MaxRecursionDepth) {
		_NSTypeEncodingFail(ctx, p, 'd');
		return nullptr;
	}

	if (p >= ctx->end) {
		_NSTypeEncodingFail(ctx, p, 'c');
		return nullptr;
	}

	/* Skip all qualifiers and guard against walking off the end. */
	while (p < ctx->end && _NSTypeEncodingIsQualifier(*p))
		++p;

	if (p >= ctx->end) {
		_NSTypeEncodingFail(ctx, p, 'c');
		return nullptr;
	}

	switch (*p) {
	/* Scalar leaves common to both schemes. */
	case 'c': case 'i': case 's': case 'l': case 'q':
	case 'C': case 'I': case 'S': case 'L': case 'Q':
	case 'f': case 'd': case 'B':
	case 'v': case '*': case '#': case ':': case '?':
		return p + 1;

	/* id (@) or a block (@?). */
	case '@':
		++p;
		if (p < ctx->end && *p == '?')
			return p + 1;

		return p;

	/* pointer(s) to one type */
	case '^':
		while (p < ctx->end && *p == '^')
			++p;

		return _NSTypeEncodingParse(ctx, p, depth + 1);

	case '[':
		return _NSTypeEncodingParseArray(ctx, p, depth);

	case '{':
		return _NSTypeEncodingParseAggregate(ctx, p, depth, '{', '}');

	/* Union: lexically valid, but not invocable. */
	case '(':
		if (invocable) {
			_NSTypeEncodingFail(ctx, p, 'u');
			return nullptr;
		}

		return _NSTypeEncodingParseAggregate(ctx, p, depth, '(', ')');

	/* Bitfield: lexically valid, but not invocable. */
	case 'b':
		if (invocable) {
			_NSTypeEncodingFail(ctx, p, 'u');
			return nullptr;
		}

		return _NSTypeEncodingParseBitfield(ctx, p);

	/* _Complex: lexically valid, but not invocable. */
	case 'j':
		if (invocable) {
			_NSTypeEncodingFail(ctx, p, 'u');
			return nullptr;
		}

		++p;
		if (p >= ctx->end || _NSTypeEncodingIsComplexScalar(*p) == false) {
			_NSTypeEncodingFail(ctx, p, 'c');
			return nullptr;
		}

		return p + 1;

	/* long double (D) and __int128 (t/T): lexically valid, but not invocable. */
	case 'D':
	case 't':
	case 'T':
		if (invocable) {
			_NSTypeEncodingFail(ctx, p, 'u');
			return nullptr;
		}

		return p + 1;

	/* A closing bracket where a type was expected. */
	case ']':
	case '}':
	case ')':
		_NSTypeEncodingFail(ctx, p, ']');
		return nullptr;
	}

	/* '"', '<', '>', or any other junk. */
	_NSTypeEncodingFail(ctx, p, 'c');
	return nullptr;
}

/* One past the balanced close of the aggregate opening at start. Returns end if it is never closed. */
static char const *
_NSTypeEncodingAggregateEnd(char const *start, char const *end)
{
	NSUInteger depth = 0;

	for (char const *p = start; p < end; ++p) {
		switch (*p) {
		case '{': case '[': case '(':
			++depth;
			break;

		case '}': case ']': case ')':
			if (--depth == 0)
				return p + 1;

			break;
		}
	}

	return end;
}

/* Build a failure message upon failing to validate a type component. */
[[clang::always_inline]]
static inline NSTypeEncodingStringResult
_NSTypeEncodingBuildResult(ValidateContext *ctx)
{
	NSString *inAggregate = @"";
	NSString *reason;

	/* If we errored out in an aggregate, display it. */
	if ((ctx->errKind == 'c' || ctx->errKind == 'u' || ctx->errKind == 'b' || ctx->errKind == 'A' ||
	    ctx->errKind == 'W') && ctx->topAggregate != nullptr) {
		char const *aggregateEnd = _NSTypeEncodingAggregateEnd(ctx->topAggregate, ctx->end);
		NSString *snippet = [[NSString alloc] initWithBytes:ctx->topAggregate
					length:(NSUInteger)(aggregateEnd - ctx->topAggregate)
						encoding:NSASCIIStringEncoding];

		inAggregate = [NSString stringWithFormat:@" (in '%@')", snippet];
	}

	switch (ctx->errKind) {
	case 'c':
		reason = ctx->errAt >= ctx->end
			? @"unexpected end of type-encoding string."
			: [NSString stringWithFormat:@"invalid type encoding specifier '%c'%@.", *ctx->errAt,
				inAggregate];
		break;

	case 'u':
		reason = [NSString stringWithFormat:@"unsupported type encoding specifier '%c'%@.", *ctx->errAt,
				inAggregate];
		break;

	case 'b':
		reason = ctx->errAt >= ctx->end
			? @"expected a digit after 'b' in a bitfield, but the type-encoding string ended."
			: [NSString stringWithFormat:@"expected a digit after 'b' in a bitfield, got '%c'%@.",
				*ctx->errAt, inAggregate];
		break;

	case ']':
		reason = [NSString stringWithFormat:@"unexpected closing bracket '%c'.", *ctx->errAt];
		break;

	case '{':
		reason = @"missing closing bracket for struct at end of type-encoding string.";
		break;

	case '[':
		reason = @"missing closing bracket for array at end of type-encoding string.";
		break;

	case '(':
		reason = @"missing closing bracket for union at end of type-encoding string.";
		break;

	case 'd':
		reason = @"type encoding is nested too deeply.";
		break;

	case 'A':
		reason = [NSString stringWithFormat:@"array count is too large in type-encoding string%@.",
				inAggregate];
		break;

	case 'W':
		reason = [NSString stringWithFormat:@"bitfield width is too large in type-encoding string%@.",
				inAggregate];
		break;

	case 'F':
		reason = @"frame offset is too large in type-encoding string.";
		break;

	case 'S':
		reason = @"type size, alignment rounding, or leaf count is too large in type-encoding string.";
		break;

	default:
		reason = @"malformed type encoding.";
		break;
	}

	return (NSTypeEncodingStringResult){ ctx->status, reason };
}

NSTypeEncodingStringResult
NSTypeEncodingStringValidate(NSTypeEncodingStringScheme scheme, char const *types)
{
	/* You can never be too careful with all the caffeine pumping through the average programmer's veins! */
	if ((unsigned char)scheme > (unsigned char)NSTypeEncodingStringSchemeInvocable)
		[NSException raise:NSInvalidArgumentException format:@"%s: scheme was invalid.", __PRETTY_FUNCTION__];

	ValidateContext ctx = {
		.end = types + strlen(types),
		.scheme = scheme,
		.status = NSTypeEncodingStringStatusOK,
		.errAt = nullptr,
		.errKind = 0,
		.topAggregate = nullptr
	};

	for (char const *p = types; p < ctx.end; ) {
		char const *q;
		NSUInteger sizeBits, alignBits, leaves;
		[[maybe_unused]] NSUInteger offset;

		/* If parsing a component failed, fail now. */
		if ((q = _NSTypeEncodingParse(&ctx, p, 0)) == nullptr)
			return _NSTypeEncodingBuildResult(&ctx);

		/*
		 * Syntax and numeric tokens are now safe to measure. Reject layout overflow before callers reach
		 * the trusted public measurer; use the same arithmetic for both validation schemes.
		 */
		if (_NSTypeEncodingMeasure(p, &sizeBits, &alignBits, &leaves) == nullptr) {
			_NSTypeEncodingFail(&ctx, p, 'S');
			return _NSTypeEncodingBuildResult(&ctx);
		}

		/* Move past the frame offset, rejecting one too large to represent. */
		p = q;
		if (_NSTypeEncodingScanDigits(&p, &offset) == false) {
			_NSTypeEncodingFail(&ctx, q, 'F');
			return _NSTypeEncodingBuildResult(&ctx);
		}
	}

	return (NSTypeEncodingStringResult){ NSTypeEncodingStringStatusOK, nil };
}

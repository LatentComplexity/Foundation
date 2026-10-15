
#import <FoundationPrivate/NSObject/NSObject.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <FoundationPrivate/NSObject/NSTypeEncodingString.h>

#include <Block.h>
#include <objc/hooks.h>
#include <objc/message.h>

#pragma mark - Types and Structures

/* Round an integer x upward to the next multiple of a. a must be a power of two. */
#define _NSInvocationAlignUp(x, a) (((x) + ((a) - 1)) & ~((size_t)(a) - 1))

/*
 * AAPCS64 argument categories arising from the permitted type set. Where the System V ABI classifies eightbytes, the
 * AAPCS classifies whole arguments.
 */
typedef enum AAPCS64Class : unsigned char {
	EMPTY = 0, /* Zero-sized aggregate (or void); materializes in no register and no stack slot. */
	INTEGRAL, /* Integers, pointers, and friends; one GP register (C.7). */
	HFA, /* One to four homogeneous float or double members; one SIMD register per member (C.1/C.2). */
	COMPOSITE, /* Non-HFA aggregate of at most 16 bytes; one GP register per eightbyte (C.10). */
	INDIRECT /* Non-HFA aggregate larger than 16 bytes; replaced by a pointer to a caller-owned copy (B.5). */
} AAPCS64Class;

/* AAPCS64 classification details. */
typedef struct NSInvocationClassInfo {
	NSUInteger size; /* The size of the type as given by NSTypeEncodingStringSizeOf(). */
	AAPCS64Class kind;
	char hfaBase; /* 'f' or 'd'; valid iff kind == HFA. */
	unsigned char hfaCount; /* 1 through 4; valid iff kind == HFA. */
	unsigned char regCount; /* Registers consumed when not on the stack: SIMD for HFA, GP for everything else. */
	char padding[4];
} NSInvocationClassInfo;

typedef struct NSInvocationReturnValueInfo {
	NSInvocationClassInfo classInfo;
	char const *type; /* Unqualified type borrowed from our method signature; the signature keeps the original spelling. */
	char *returnBuffer; /* Valid iff classInfo.size > 0. Written into directly, or re-assembled. */
} NSInvocationReturnValueInfo;

typedef struct NSInvocationArgumentInfo {
	NSInvocationClassInfo classInfo;
	char const *type; /* Unqualified type borrowed from our method signature; the signature keeps the original spelling. */
	char *bytes; /* Stored argument. nullptr for empty aggregates. Must be freed. */
	unsigned char registerIndex; /* First register in the bank implied by kind; valid iff onStack == false. */
	bool onStack; /* True upon register exhaustion (C.3, C.11) or an exhausted INDIRECT pointer. */
	char padding[6];
	NSUInteger stackOffset; /* Position of argument on stack; valid iff onStack == true. */
	NSUInteger indirectOffset; /* Position of the callee-visible copy, relative to the end of the stack image;
				      valid iff kind == INDIRECT. */
} NSInvocationArgumentInfo;

typedef struct NSInvocationRegisters {
	unsigned long GPRegisters[8]; /* x0-x7. */
	unsigned long indirectReturn; /* x8, the indirect result location register. */
	double FPRegisters[8]; /* d0-d7; the low half of v0-v7 is all the permitted type set can ever populate. */
	char *stack;
	unsigned long stackSize;
	IMP impToInvoke;
	unsigned long returnRegisters[6]; /* x0, x1, d0, d1, d2, d3. HFA returns need all four SIMD slots. */
} NSInvocationRegisters;

static_assert(offsetof(NSInvocationRegisters, GPRegisters) == 0);
static_assert(offsetof(NSInvocationRegisters, indirectReturn) == 64);
static_assert(offsetof(NSInvocationRegisters, FPRegisters) == 72);
static_assert(offsetof(NSInvocationRegisters, stack) == 136);
static_assert(offsetof(NSInvocationRegisters, stackSize) == 144);
static_assert(offsetof(NSInvocationRegisters, impToInvoke) == 152);
static_assert(offsetof(NSInvocationRegisters, returnRegisters) == 160);

typedef struct NSInvocationForwardingRegisters {
	unsigned long GPRegisters[8];
	unsigned long indirectReturn;
	double FPRegisters[8];
	char *stack;
	unsigned long returnRegisters[6];
} NSInvocationForwardingRegisters;

static_assert(offsetof(NSInvocationForwardingRegisters, GPRegisters) == 0);
static_assert(offsetof(NSInvocationForwardingRegisters, indirectReturn) == 64);
static_assert(offsetof(NSInvocationForwardingRegisters, FPRegisters) == 72);
static_assert(offsetof(NSInvocationForwardingRegisters, stack) == 136);
static_assert(offsetof(NSInvocationForwardingRegisters, returnRegisters) == 144);

#pragma mark - Internal Declarations

/* Trampolines in NSInvocationTrampolines.S. */
[[gnu::visibility("hidden")]]
extern void
NSInvocationCall(NSInvocationRegisters *);

[[gnu::visibility("hidden")]]
extern void
NSInvocationForward(void);

/* libobjc2 proxy lookup hook. */
static id
_NSInvocationProxyLookup(id, SEL);

/* libobjc2 forwarding hook. */
static IMP
_NSInvocationForwardHook(id, SEL);

/* Forwarding handler called from the forwarding trampoline. */
[[gnu::visibility("hidden")]]
extern void
NSInvocationForwardHandler(NSInvocationForwardingRegisters *);

@interface NSInvocation ()

- (instancetype)_initWithMethodSignature:(NSMethodSignature *)methodSignature
		forwardingRegisters:(NSInvocationForwardingRegisters *)registers OBJC_DIRECT;
- (void)_retainReturnValue OBJC_DIRECT;
- (void)_releaseReturnValue OBJC_DIRECT;
- (void)_retainArgumentAtIndex:(NSUInteger)index OBJC_DIRECT;
- (void)_releaseArgumentAtIndex:(NSUInteger)index OBJC_DIRECT;

@end

@implementation NSInvocation {
	NSInvocationReturnValueInfo _returnInfo;
	NSInvocationArgumentInfo *_argumentsInfo;
	NSUInteger _numberOfArguments;
	NSInvocationRegisters _invocationFrame;
}

@synthesize methodSignature = _methodSignature;
@synthesize target = _target;
@synthesize selector = _selector;
@synthesize argumentsRetained = _argumentsRetained;

#pragma mark - Classification

/*
 * Decide whether a type is a Homogeneous Floating-point Aggregate: every leaf must be the same one of 'f' or 'd', and
 * there may be at most four of them. The first leaf seen elects the base type. Returns false the moment the type is
 * disqualified. A lone float or double deliberately passes as a one-member HFA; the AAPCS rules for passing (C.1
 * versus C.2) and returning (v0) a fundamental floating-point type coincide exactly with that reading.
 */
static bool
_NSInvocationHFAWalk(char const *type, char *base, unsigned char *count)
{
	type = _NSTypeEncodingSkipQualifier(type);

	switch (*type) {
	case 'f':
	case 'd':
		if (*base == 0)
			*base = *type;
		else if (*base != *type)
			return false;

		return ++*count <= 4;

	/* Array: [<count><element>] */
	case '[': {
		char const *elem = type + 1;
		NSUInteger n = 0;

		while (*elem >= '0' && *elem <= '9')
			n = n * 10 + (NSUInteger)(*elem++ - '0');

		/* Each element contributes its own leaves; the count check above bounds runaway arrays. */
		for (NSUInteger k = 0; k < n; ++k)
			if (_NSInvocationHFAWalk(elem, base, count) == false)
				return false;

		return true;
	}

	/* Structure: {tag=<fields>} */
	case '{': {
		char const *p = type + 1;

		/* Skip the tag. */
		while (*p != '\0' && *p != '=' && *p != '}')
			++p;
		if (*p == '=')
			++p;

		while (*p != '\0' && *p != '}') {
			if (_NSInvocationHFAWalk(p, base, count) == false)
				return false;

			p = NSTypeEncodingStringSkip(p);
		}

		return true;
	}

	default:
		/* An integer, pointer, or any other non-floating leaf disqualifies the aggregate. */
		return false;
	}
}

[[clang::always_inline]]
static void
_NSInvocationClassify(char const *type, NSInvocationClassInfo *classInfo)
{
	char base = 0;
	unsigned char count = 0;

	type = _NSTypeEncodingSkipQualifier(type);
	classInfo->size = NSTypeEncodingStringSizeOf(type);

	/* Empty aggregates and void materialize nowhere. */
	if (classInfo->size == 0) {
		classInfo->kind = EMPTY;
		classInfo->regCount = 0;
		return;
	}

	/*
	 * HFAs come first: a homogeneous aggregate of one to four floats or doubles travels one member per SIMD
	 * register even when it is larger than 16 bytes ({dddd} is 32 bytes and still register-resident). The size
	 * rules below must therefore never see it.
	 */
	if (_NSInvocationHFAWalk(type, &base, &count) == true && count != 0) {
		classInfo->kind = HFA;
		classInfo->hfaBase = base;
		classInfo->hfaCount = count;
		classInfo->regCount = count;
		return;
	}

	/* Non-HFA aggregates: at most 16 bytes rides in GP registers; anything bigger degrades to a pointer (B.5). */
	if (*type == '{' || *type == '[') {
		if (classInfo->size > 16) {
			classInfo->kind = INDIRECT;
			classInfo->regCount = 1;
		} else {
			classInfo->kind = COMPOSITE;
			classInfo->regCount = (unsigned char)((classInfo->size + 7) / 8);
		}

		return;
	}

	/* Everything else the signature permits is a scalar in a single GP register. */
	classInfo->kind = INTEGRAL;
	classInfo->regCount = 1;
}

#pragma mark - Runtime Hooks

static id
_NSInvocationProxyLookup(id receiver, SEL aSel)
{
	/* Step #1: Call -forwardingTargetForSelector:. */
	id target = [(NSObject *)receiver forwardingTargetForSelector:aSel];

	/* Return the new target only if it actually is a new target. */
	return target == receiver ? nil : target;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-strict"

/* The forwarding hook can't fail on arm64, so it's static. Its presence is irrelevant in a stack trace. */
static IMP
_NSInvocationForwardHook(id receiver, SEL aSel)
{
	Class c;
	bool resolved;

	/* class_getMethodImplementation() called us. Defer the whole lookup. */
	if (receiver == nil)
		return (IMP)objc_msgSend;

	/* Step #2: Get the instance's class and call the appropriate method. */
	c = object_getClass(receiver);
	resolved = class_isMetaClass(c) ? [(Class)receiver resolveClassMethod:aSel] : [c resolveInstanceMethod:aSel];

	/* If the call returned true and the class does indeed respond to the selector, return its IMP. */
	if (resolved && class_respondsToSelector(c, aSel))
		return class_getMethodImplementation(c, aSel);

	/* Step #3: Otherwise, hand back the forwarding trampoline. */
	return (IMP)NSInvocationForward;
}

#pragma clang diagnostic pop

#pragma mark - Forwarding

[[gnu::visibility("hidden")]]
extern void
NSInvocationForwardHandler(NSInvocationForwardingRegisters *r)
{
	/* Grab our target and selector. */
	NSObject *__unsafe_unretained target = (__bridge NSObject *__unsafe_unretained)(void *)r->GPRegisters[0];
	SEL const aSel = (SEL)(uintptr_t)r->GPRegisters[1];

	/* Ask the target to describe the call through -methodSignatureForSelector:. */
	NSMethodSignature *sig;
	if ((sig = [target methodSignatureForSelector:aSel]) == nil)
		[target doesNotRecognizeSelector:aSel];

	/* Create the invocation object. */
	NSInvocation *invocation = [[NSInvocation alloc] _initWithMethodSignature:sig forwardingRegisters:r];

	/* Go! */
	[target forwardInvocation:invocation];

	/* Classify the return value and put it back where the original caller expects it. */
	NSInvocationClassInfo classInfo;
	_NSInvocationClassify(sig.methodReturnType, &classInfo);

	switch (classInfo.kind) {
	case EMPTY:
		break;

	case INDIRECT:
		/* The caller handed us the address of its return slot in x8; fill it in place. */
		[invocation getReturnValue:(void *)(uintptr_t)r->indirectReturn];
		break;

	case HFA: {
		NSUInteger const memberSize = classInfo.hfaBase == 'f' ? 4 : 8;
		char retVal[32] = { 0 };

		/* One member per SIMD register; floats occupy the low 32 bits of their slot. */
		[invocation getReturnValue:retVal];
		for (unsigned char k = 0; k < classInfo.hfaCount; ++k) {
			r->returnRegisters[2 + k] = 0;
			memcpy(&r->returnRegisters[2 + k], retVal + k * memberSize, memberSize);
		}

		break;
	}

	case INTEGRAL:
	case COMPOSITE: {
		unsigned long retVal[2] = { 0 };

		/* x0 and x1 live side by side in the bank; small returns drop straight in. */
		[invocation getReturnValue:retVal];
		r->returnRegisters[0] = retVal[0];
		r->returnRegisters[1] = retVal[1];
		break;
	}
	}
}

+ (void)load
{
	objc_proxy_lookup = _NSInvocationProxyLookup;
	__objc_msg_forward2 = _NSInvocationForwardHook;
}

#pragma mark - Property Setters

- (void)setTarget:(id __unsafe_unretained)aTarget
{
	if (_argumentsRetained == true) {
		objc_retain(aTarget);
		objc_release(_target);
		_target = aTarget;
	} else
		_target = aTarget;
}

#pragma mark - Initializers

+ (instancetype)invocationWithMethodSignature:(NSMethodSignature *)methodSignature
{
	_NSRequireNonnil(methodSignature);

	return [[self alloc] _initWithMethodSignature:methodSignature forwardingRegisters:nullptr];
}

- (instancetype)init
{
	_NSClusterRejectUnavailableMethodInvocation(MethodContext);
	return nil;
}

/*
 * When registers is nonnull, we were born from a forwarded message: each argument's bytes are harvested from the
 * saved registers and the caller's stack as their AAPCS64 homes are computed. When registers is null, the same layout
 * pass runs and the argument buffers simply stay zeroed.
 */
- (instancetype)_initWithMethodSignature:(NSMethodSignature *)methodSignature
		forwardingRegisters:(NSInvocationForwardingRegisters *)registers OBJC_DIRECT
{
	unsigned char NGRN = 2;
	unsigned char NSRN = 0;
	NSUInteger stackOffset = 0;
	NSUInteger indirectOffset = 0;

	/* Retain the method signature. */
	_methodSignature = methodSignature;

	/* Get the return value's type string and classify it. */
	_returnInfo.type = _NSTypeEncodingSkipQualifier(methodSignature.methodReturnType);
	_NSInvocationClassify(_returnInfo.type, &_returnInfo.classInfo);

	/* If we return a value, make some room. Round up to 8 bytes to make register copying easy. */
	if (_returnInfo.classInfo.size != 0)
		_returnInfo.returnBuffer = calloc(1, _NSInvocationAlignUp(_returnInfo.classInfo.size, 8));

	/* When created from a forwarded message, self and _cmd are always sitting in x0 and x1. */
	if (registers != nullptr) {
		_target = (__bridge id)(void *)registers->GPRegisters[0];
		_selector = (SEL)registers->GPRegisters[1];
	}

	/* Get the total number of arguments. If we only have two, no handling of arguments is needed. */
	NSUInteger const nArgs = _numberOfArguments = methodSignature.numberOfArguments;
	if (nArgs == 2)
		return self;

	/* Allocate the argument info array. */
	_argumentsInfo = calloc(nArgs - 2, sizeof(*_argumentsInfo));

	for (NSUInteger i = 2, a = 0; i < nArgs; ++i, ++a) {
		/* Get refs to argument info and classification info; store the argument's type and classify it. */
		NSInvocationArgumentInfo *const argInfo = &_argumentsInfo[a];
		NSInvocationClassInfo *const classInfo = &(_argumentsInfo[a].classInfo);
		argInfo->type = _NSTypeEncodingSkipQualifier([methodSignature getArgumentTypeAtIndex:i]);
		/* Outermost arrays should be passed as pointers. */
		char const *type = argInfo->type;
		_NSInvocationClassify(*type == '[' ? "^v" : type, classInfo);

		/* If the argument isn't an empty aggregate, allocate space. */
		if (classInfo->size != 0)
			argInfo->bytes = calloc(1, _NSInvocationAlignUp(classInfo->size, 8));
		else
			continue; /* Empty aggregate. Please forward all complaints to your local Stallmanite. */

		switch (classInfo->kind) {
		case INTEGRAL:
		case COMPOSITE:
			/* C.7 and C.10: consecutive GP registers if the whole argument fits. */
			if (NGRN + classInfo->regCount <= 8) {
				argInfo->registerIndex = NGRN;
				NGRN += classInfo->regCount;

				if (registers != nullptr)
					for (unsigned char j = 0; j < classInfo->regCount; ++j)
						memcpy(argInfo->bytes + j * 8,
							&registers->GPRegisters[argInfo->registerIndex + j], 8);
			} else {
				/*
				 * C.11: a spilled composite slams NGRN shut; later integral arguments may not
				 * back-fill leftover GP registers. A spilled scalar only ever gets here with
				 * NGRN already at 8, so the slam is then a no-op.
				 */
				NGRN = 8;
				argInfo->onStack = true;
				stackOffset = _NSInvocationAlignUp(stackOffset, 8);
				argInfo->stackOffset = stackOffset;
				stackOffset += _NSInvocationAlignUp(classInfo->size, 8);

				if (registers != nullptr)
					memcpy(argInfo->bytes, registers->stack + argInfo->stackOffset,
						classInfo->size);
			}

			break;

		case HFA: {
			NSUInteger const memberSize = classInfo->hfaBase == 'f' ? 4 : 8;

			/* C.2: one SIMD register per member if they all fit. */
			if (NSRN + classInfo->hfaCount <= 8) {
				argInfo->registerIndex = NSRN;
				NSRN += classInfo->hfaCount;

				/* Floats occupy the low 32 bits of their register's saved slot. */
				if (registers != nullptr)
					for (unsigned char k = 0; k < classInfo->hfaCount; ++k)
						memcpy(argInfo->bytes + k * memberSize,
							&registers->FPRegisters[argInfo->registerIndex + k],
							memberSize);
			} else {
				/* C.3: a spilled HFA slams NSRN shut, exactly like C.11 does for NGRN. */
				NSRN = 8;
				argInfo->onStack = true;
				stackOffset = _NSInvocationAlignUp(stackOffset, 8);
				argInfo->stackOffset = stackOffset;
				stackOffset += _NSInvocationAlignUp(classInfo->size, 8);

				if (registers != nullptr)
					memcpy(argInfo->bytes, registers->stack + argInfo->stackOffset,
						classInfo->size);
			}

			break;
		}

		case INDIRECT:
			/*
			 * B.5: the caller passes a pointer to a copy it owns; the pointer itself is then just an
			 * integral argument. Reserve room for our own callee-visible copy past the stack image, and
			 * when forwarding, chase the caller's pointer to capture the bytes.
			 */
			argInfo->indirectOffset = indirectOffset;
			indirectOffset += _NSInvocationAlignUp(classInfo->size, 8);

			if (NGRN < 8) {
				argInfo->registerIndex = NGRN++;

				if (registers != nullptr)
					memcpy(argInfo->bytes,
						(void const *)registers->GPRegisters[argInfo->registerIndex],
						classInfo->size);
			} else {
				argInfo->onStack = true;
				stackOffset = _NSInvocationAlignUp(stackOffset, 8);
				argInfo->stackOffset = stackOffset;
				stackOffset += 8;

				if (registers != nullptr) {
					unsigned long pointerValue;

					memcpy(&pointerValue, registers->stack + argInfo->stackOffset, 8);
					memcpy(argInfo->bytes, (void const *)pointerValue, classInfo->size);
				}
			}

			break;

		case EMPTY:
			/* Empty aggregates were dispatched above and never get here. */
			/* TODO: Consider trapping, maybe? Will have to look more into this. */
			/* __builtin_trap(); */
			break;
		}
	}

	/*
	 * Allocate the call frame's spill block: the stack image first (the stack is always 16-byte aligned on
	 * arm64), then the callee-visible copies of by-reference arguments, which live past stackSize so that the
	 * trampoline never copies them onto the real stack.
	 */
	_invocationFrame.stackSize = _NSInvocationAlignUp(stackOffset, 16);
	if (_invocationFrame.stackSize + indirectOffset != 0)
		_invocationFrame.stack = calloc(1, _invocationFrame.stackSize + indirectOffset);

	return self;
}

#pragma mark - Helpers

/*
 * Acquire a pointer slot before releasing its predecessor. The source may contain a borrowed pointer into
 * the old value (including a C-string suffix). Block encodings require a heap copy, not objc_retain().
 */
[[clang::always_inline]]
static inline void *
_NSInvocationAcquireValue(char const *type, void const *source)
{
	void *value;

	__builtin_memcpy_inline(&value, source, sizeof(value));

	if (value == nullptr)
		return nullptr;

	/*
	 * libobjc2's upstream implementation of objc_retain() violates the ARC spec and always retains a Block, even
	 * if it's a stack Block. objc_retain()'s return value should always be pointer-identical to its input, and
	 * our local fork corrects that behaviour. Thus, we cannot indiscriminately funnel all Blocks into
	 * objc_retain(), and so we use Block_copy() like normal people.
	 */
	if (type[0] == '@') {
		if (type[1] == '?')
			return Block_copy(value);
		objc_retain((__bridge id)value);
		return value;
	}

	return strdup(value);
}

- (void)_retainReturnValue OBJC_DIRECT
{
	if (_returnInfo.returnBuffer == nullptr)
		return;

	if (_returnInfo.type[0] == '@' || _returnInfo.type[0] == '*') {
		void *value = _NSInvocationAcquireValue(_returnInfo.type, _returnInfo.returnBuffer);
		__builtin_memcpy_inline(_returnInfo.returnBuffer, &value, sizeof(value));
	}
}

- (void)_releaseReturnValue OBJC_DIRECT
{
	if (_returnInfo.returnBuffer == nullptr)
		return;

	if (_returnInfo.type[0] == '@') {
		if (_returnInfo.type[1] == '?')
			Block_release(*(void **)(uintptr_t)_returnInfo.returnBuffer);
		else
			objc_release((__bridge id __unsafe_unretained)*(void **)(uintptr_t)_returnInfo.returnBuffer);
	} else if (_returnInfo.type[0] == '*')
		free(*(char **)(uintptr_t)_returnInfo.returnBuffer);
}

- (void)_retainArgumentAtIndex:(NSUInteger)index OBJC_DIRECT
{
	if (index == 0)
		objc_retain(_target);
	else if (index > 1) {
		NSInvocationArgumentInfo *argInfo = &_argumentsInfo[index - 2];

		if (argInfo->type[0] == '@' || argInfo->type[0] == '*') {
			void *value = _NSInvocationAcquireValue(argInfo->type, argInfo->bytes);
			__builtin_memcpy_inline(argInfo->bytes, &value, sizeof(value));
		}
	}
}

- (void)_releaseArgumentAtIndex:(NSUInteger)index OBJC_DIRECT
{
	if (index == 0)
		objc_release(_target);
	else if (index > 1) {
		NSInvocationArgumentInfo *argInfo = &_argumentsInfo[index - 2];

		if (argInfo->type[0] == '@') {
			if (argInfo->type[1] == '?')
				Block_release(*(void **)(uintptr_t)argInfo->bytes);
			else
				objc_release((__bridge id __unsafe_unretained)*(void **)(uintptr_t)argInfo->bytes);
		} else if (argInfo->type[0] == '*')
			free(*(char **)(uintptr_t)argInfo->bytes);
	}
}

#pragma mark - Methods

- (void)setReturnValue:(void *)returnValueLocation
{
	_NSRequireNonnullptr(returnValueLocation);

	if (_argumentsRetained == true && (_returnInfo.type[0] == '@' || _returnInfo.type[0] == '*')) {
		void *value = _NSInvocationAcquireValue(_returnInfo.type, returnValueLocation);
		[self _releaseReturnValue];
		__builtin_memcpy_inline(_returnInfo.returnBuffer, &value, sizeof(value));
		return;
	}

	memcpy(_returnInfo.returnBuffer, returnValueLocation, _returnInfo.classInfo.size);
}

- (void)getReturnValue:(void *)returnValueLocation
{
	_NSRequireNonnullptr(returnValueLocation);

	memcpy(returnValueLocation, _returnInfo.returnBuffer, _returnInfo.classInfo.size);
}

- (void)setArgument:(void *)argumentLocation atIndex:(NSUInteger)index
{
	NSUInteger argSize;
	NSUInteger argSlotSize;

	_NSRequireNonnullptr(argumentLocation);

	if (index >= _numberOfArguments)
		_NSRaiseException(MethodContext, NSRangeException, @"index out of bounds.");

	/* Acquire before releasing: callers may pass back a value borrowed with getArgument:. */
	if (_argumentsRetained == true) {
		char const *type = index == 0 ? "@" : index == 1 ? ":" : _argumentsInfo[index - 2].type;

		if (type[0] == '@' || type[0] == '*') {
			void *value = _NSInvocationAcquireValue(type, argumentLocation);
			[self _releaseArgumentAtIndex:index];
			if (index == 0)
				_target = (__bridge id)value;
			else
				__builtin_memcpy_inline(_argumentsInfo[index - 2].bytes, &value, sizeof(value));
			return;
		}
	}

	/* Unretained values are copied without acquiring ownership. */
	if (index == 0)
		__builtin_memcpy_inline((void *)&_target, argumentLocation, sizeof(id));
	else if (index == 1)
		__builtin_memcpy_inline(&_selector, argumentLocation, sizeof(_selector));
	else {
		NSUInteger infoIndex = index - 2;

		/* Copy in the argument and zero out any 8-byte alignment. */
		argSize = _argumentsInfo[infoIndex].classInfo.size;
		argSlotSize = _NSInvocationAlignUp(argSize, 8);
		if (argSize != 0) {
			memcpy(_argumentsInfo[infoIndex].bytes, argumentLocation, argSize);
			memset(_argumentsInfo[infoIndex].bytes + argSize, 0, argSlotSize - argSize);
		}
	}
}

- (void)getArgument:(void *)argumentLocation atIndex:(NSUInteger)index
{
	_NSRequireNonnullptr(argumentLocation);

	if (index >= _numberOfArguments)
		_NSRaiseException(MethodContext, NSRangeException, @"index out of bounds.");

	if (index == 0)
		__builtin_memcpy_inline(argumentLocation, &_target, sizeof(id));
	else if (index == 1)
		__builtin_memcpy_inline(argumentLocation, &_selector, sizeof(SEL));
	else {
		NSUInteger infoIndex = index - 2;
		NSUInteger const argSize = _argumentsInfo[infoIndex].classInfo.size;

		if (argSize != 0)
			memcpy(argumentLocation, _argumentsInfo[infoIndex].bytes, argSize);
	}
}

- (void)retainArguments
{
	if (_argumentsRetained == true)
		return;

	/* Apple: "If a return value has been set, this is also retained or copied." */
	[self _retainReturnValue];

	for (NSUInteger i = 0; i < _numberOfArguments; ++i)
		[self _retainArgumentAtIndex:i];

	_argumentsRetained = true;
}

#pragma mark - Invocation

- (void)invoke
{
	if (_selector == nullptr)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"selector was not set.");

	/* Sending a message to nil zeroes out the return value. Release it if applicable. */
	if (_target == nil) {
		if (_argumentsRetained == true)
			[self _releaseReturnValue];

		memset(_returnInfo.returnBuffer, 0, _returnInfo.classInfo.size);
		return;
	}

	[self invokeUsingIMP:class_getMethodImplementation(object_getClass(_target), _selector)];
}

- (void)invokeWithTarget:(id)aTarget
{
	if (_selector == nullptr)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"selector was not set.");

	self.target = aTarget;

	/* Sending a message to nil zeroes out the return value. Release it if applicable. */
	if (_target == nil) {
		if (_argumentsRetained == true)
			[self _releaseReturnValue];

		memset(_returnInfo.returnBuffer, 0, _returnInfo.classInfo.size);
		return;
	}

	[self invokeUsingIMP:class_getMethodImplementation(object_getClass(_target), _selector)];
}

- (void)invokeUsingIMP:(IMP)anIMP
{
	if (_selector == nullptr)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"selector was not set.");

	_NSRequireNonnullptr((void *)(uintptr_t)anIMP);

	/* We are about to overwrite the return value; relinquish any retained value we currently hold. */
	if (_argumentsRetained == true)
		[self _releaseReturnValue];

	if (_target == nil) {
		memset(_returnInfo.returnBuffer, 0, _returnInfo.classInfo.size);
		return;
	}

	/* Set the IMP we're jumping to. */
	_invocationFrame.impToInvoke = anIMP;

	/* Indirect returns travel through x8; self and _cmd keep x0 and x1 no matter what. */
	_invocationFrame.indirectReturn = _returnInfo.classInfo.kind == INDIRECT ?
		(unsigned long)_returnInfo.returnBuffer : 0UL;
	_invocationFrame.GPRegisters[0] = (unsigned long)(uintptr_t)_target;
	_invocationFrame.GPRegisters[1] = (unsigned long)(uintptr_t)(void *)_selector;

	/* For all real arguments in the argument array; place their bytes where they belong. */
	for (NSUInteger i = 0; i < _numberOfArguments - 2; ++i) {
		NSInvocationArgumentInfo *argInfo;
		NSInvocationClassInfo *classInfo;

		argInfo = &_argumentsInfo[i];
		classInfo = &argInfo->classInfo;

		switch (classInfo->kind) {
		case EMPTY:
			continue;

		case INDIRECT: {
			/*
			 * Refresh the callee-visible copy: the callee owns it for the duration of the call and may
			 * scribble on it, so the stored argument bytes are never handed out directly. The pointer
			 * to the copy is then planted like any integral argument.
			 */
			char *copy = _invocationFrame.stack + _invocationFrame.stackSize + argInfo->indirectOffset;
			unsigned long const pointerValue = (unsigned long)(uintptr_t)copy;

			memcpy(copy, argInfo->bytes, classInfo->size);

			if (argInfo->onStack == true)
				memcpy(_invocationFrame.stack + argInfo->stackOffset, &pointerValue, 8);
			else
				_invocationFrame.GPRegisters[argInfo->registerIndex] = pointerValue;

			break;
		}

		case HFA: {
			if (argInfo->onStack == true) {
				memcpy(_invocationFrame.stack + argInfo->stackOffset, argInfo->bytes,
					classInfo->size);
				break;
			}

			NSUInteger const memberSize = classInfo->hfaBase == 'f' ? 4 : 8;

			/* One member per SIMD register; floats occupy the low 32 bits of their slot. */
			for (unsigned char k = 0; k < classInfo->hfaCount; ++k) {
				_invocationFrame.FPRegisters[argInfo->registerIndex + k] = 0.0;
				memcpy(&_invocationFrame.FPRegisters[argInfo->registerIndex + k],
					argInfo->bytes + k * memberSize, memberSize);
			}

			break;
		}

		case INTEGRAL:
		case COMPOSITE:
			/* If we live on the stack, copy our bytes to our desired stack offset. */
			if (argInfo->onStack == true) {
				memcpy(_invocationFrame.stack + argInfo->stackOffset, argInfo->bytes,
					classInfo->size);
				break;
			}

			/*
			 * Copying eight bytes indiscriminately works for two reasons: we take care to zero out
			 * unused bytes when assigning arguments into their byte buffers, and these buffers are
			 * always 8-byte aligned. This makes copying, say, 12 byte structures a lot more convenient.
			 */
			for (unsigned char j = 0; j < classInfo->regCount; ++j)
				memcpy(&_invocationFrame.GPRegisters[argInfo->registerIndex + j],
					argInfo->bytes + j * 8, 8);

			break;
		}
	}

	/* Go! */
	NSInvocationCall(&_invocationFrame);

	/* Reassemble the return value from the return banks. Indirect returns were written in place via x8. */
	switch (_returnInfo.classInfo.kind) {
	case EMPTY:
	case INDIRECT:
		return; /* TODO: is this the right move?
			 * Should this case intentionally skip over retaining the return value? */

	case HFA: {
		NSUInteger const memberSize = _returnInfo.classInfo.hfaBase == 'f' ? 4 : 8;

		for (unsigned char k = 0; k < _returnInfo.classInfo.hfaCount; ++k)
			memcpy(_returnInfo.returnBuffer + k * memberSize,
				&_invocationFrame.returnRegisters[2 + k], memberSize);

		break;
	}

	case INTEGRAL:
	case COMPOSITE:
		/* x0 and x1 live side by side in the bank; a single bounded copy reassembles any small return. */
		memcpy(_returnInfo.returnBuffer, &_invocationFrame.returnRegisters[0],
			_returnInfo.classInfo.size);
		break;
	}

	/* When arguments are retained, the freshly-produced return value is owned by us too. */
	if (_argumentsRetained == true)
		[self _retainReturnValue];
}

- (void)dealloc
{
	/* Release the return value if we owned it, then free its buffer. */
	if (_argumentsRetained == true)
		[self _releaseReturnValue];

	free(_returnInfo.returnBuffer);

	/* Release object and C string arguments if we retained them. */
	if (_argumentsRetained == true)
		for (NSUInteger i = 0; i < _numberOfArguments; ++i)
			[self _releaseArgumentAtIndex:i];

	/* For every argument, release its backing bytes, then the array itself. */
	if (_argumentsInfo != nullptr) {
		/* Empty aggregates have no byte buffer, but do take up space in the arguments array. */
		for (NSUInteger i = 0; i < _numberOfArguments - 2; ++i)
			free(_argumentsInfo[i].bytes);

		/* Free the arguments array. */
		free(_argumentsInfo);
	}

	/* Free the stack. */
	free(_invocationFrame.stack);
}

@end

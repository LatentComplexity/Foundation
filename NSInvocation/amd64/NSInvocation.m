
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

/* System V ABI classes arising from the permitted type set. */
typedef enum SystemVClass : unsigned char {
	NONE = 0,
	INTEGER,
	SSE,
	MEMORY
} SystemVClass;

/* System V classification details. */
typedef struct NSInvocationClassInfo {
	NSUInteger size; /* The size of the type as given by NSTypeEncodingStringSizeOf(). */
	unsigned char eightbyteCount; /* 0, 1, or 2. */
	SystemVClass eightbyteClasses[2]; /* Valid for indices < eightbyteCount; INTEGER or SSE. */
	char padding[5];
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
	unsigned char eightbyteRegisterIndices[2]; /* Valid iff onStack == false. */
	bool onStack; /* Valid if argument is classified as MEMORY, or upon required register exhaustion. */
	char padding[5];
	NSUInteger stackOffset; /* Position of argument on stack; valid iff onStack == true. */
} NSInvocationArgumentInfo;

typedef struct NSInvocationRegisters {
	unsigned long GPRegisters[6];
	double SSERegisters[8];
	char *stack;
	unsigned long stackSize;
	IMP impToInvoke;
	unsigned long returnRegisters[4];
} NSInvocationRegisters;

static_assert(offsetof(NSInvocationRegisters, GPRegisters) == 0);
static_assert(offsetof(NSInvocationRegisters, SSERegisters) == 48);
static_assert(offsetof(NSInvocationRegisters, stack) == 112);
static_assert(offsetof(NSInvocationRegisters, stackSize) == 120);
static_assert(offsetof(NSInvocationRegisters, impToInvoke) == 128);
static_assert(offsetof(NSInvocationRegisters, returnRegisters) == 136);

typedef struct NSInvocationForwardingRegisters {
	unsigned long GPRegisters[6];
	double SSERegisters[8];
	char *stack;
	unsigned long returnRegisters[4];
} NSInvocationForwardingRegisters;

static_assert(offsetof(NSInvocationForwardingRegisters, GPRegisters) == 0);
static_assert(offsetof(NSInvocationForwardingRegisters, SSERegisters) == 48);
static_assert(offsetof(NSInvocationForwardingRegisters, stack) == 112);
static_assert(offsetof(NSInvocationForwardingRegisters, returnRegisters) == 120);

#pragma mark - Internal Declarations

/* Trampolines in NSInvocationTrampolines.S. */
[[gnu::visibility("hidden")]]
extern void
NSInvocationCall(NSInvocationRegisters *);

[[gnu::visibility("hidden")]]
extern void
NSInvocationForward(void);

[[gnu::visibility("hidden")]]
extern void
NSInvocationForwardStret(void);

/* libobjc2 proxy lookup hook. */
static id
_NSInvocationProxyLookup(id, SEL);

/* libobjc2 forwarding hook. */
[[gnu::visibility("hidden")]]
IMP
_NSInvocationForwardHook(id, SEL);

/* Forwarding handler called from the forwarding trampolines. */
[[gnu::visibility("hidden")]]
extern void
NSInvocationForwardHandler(NSInvocationForwardingRegisters *, bool);

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
 * Merge two eightbyte classes per the System V rules: NO_CLASS is the identity, MEMORY dominates everything. INTEGER
 * dominates SSE. No permitted leaf is ever MEMORY-classed, but the rule is kept in case the accepted type set widens.
 */
[[clang::always_inline]]
static inline SystemVClass
_NSInvocationMerge(SystemVClass a, SystemVClass b)
{
	if (a == b)
		return a;
	if (a == NONE)
		return b;
	if (b == NONE)
		return a;
	if (a == MEMORY || b == MEMORY)
		return MEMORY;

	/* The only remaining mix is INTEGER + SSE. */
	return INTEGER;
}

static void
_NSInvocationWalk(char const *type, NSUInteger offset, SystemVClass ebClasses[2])
{
	type = _NSTypeEncodingSkipQualifier(type);

	switch (*type) {
	case 'f':
	case 'd':
		ebClasses[offset / 8] = _NSInvocationMerge(ebClasses[offset / 8], SSE);
		return;

	case 'c': case 'i': case 's': case 'l': case 'q':
	case 'C': case 'I': case 'S': case 'L': case 'Q':
	case 'B':
	case '*': case '@': case '#': case ':': case '^':
		ebClasses[offset / 8] = _NSInvocationMerge(ebClasses[offset / 8], INTEGER);
		return;

	/* Array: [<count><element>] */
	case '[': {
		char const *elem = type + 1;
		NSUInteger count = 0;

		while (*elem >= '0' && *elem <= '9')
			count = count * 10 + (size_t)(*elem++ - '0');

		NSUInteger stride = NSTypeEncodingStringSizeOf(elem);

		for (NSUInteger k = 0; k < count; ++k)
			_NSInvocationWalk(elem, offset + k * stride, ebClasses);

		return;
	}

	/* Structure: {tag=<fields>} */
	case '{': {
		char const *p = type + 1;
		NSUInteger cur = offset;

		/* Skip the tag. */
		while (*p != '\0' && *p != '=' && *p != '}')
			++p;
		if (*p == '=')
			++p;

		while (*p != '\0' && *p != '}') {
			NSUInteger align = NSTypeEncodingStringAlignOf(p);

			cur = _NSInvocationAlignUp(cur, align != 0 ? align : 1);
			_NSInvocationWalk(p, cur, ebClasses);
			cur += NSTypeEncodingStringSizeOf(p);
			p = NSTypeEncodingStringSkip(p);
		}

		return;
	}

	default:
		__builtin_trap();
	}
}

[[clang::always_inline]]
static void
_NSInvocationClassify(char const *type, NSInvocationClassInfo *classInfo)
{
	SystemVClass ebClasses[2] = { NONE, NONE };

	classInfo->size = NSTypeEncodingStringSizeOf(type);

	/* If size > 16, we are MEMORY. If size == 0, we are an empty aggregate. */
	if (classInfo->size > 16 || classInfo->size == 0) {
		classInfo->eightbyteCount = 0;
		return;
	}

	_NSInvocationWalk(type, 0, ebClasses);

	/* We fit in either one or two eightbytes. Assign them. */
	classInfo->eightbyteCount = classInfo->size > 8 ? 2 : 1;
	for (unsigned char i = 0; i < classInfo->eightbyteCount; ++i)
		classInfo->eightbyteClasses[i] = ebClasses[i];
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

/*
 * Here's a thought: instead of returning the default non-stret msgSend if the heuristic fails, return a trampoline.
 * The trampoline saves all registers and calls a C function. Said function grabs all selectors, sorts them in
 * ascending order, then binary searches the list using the second register value. If the routine is stret, the
 * search will yield nothing. Otherwise, you get a hit and know to use the plain msgSend variant.
 *
 * Of course, this whole scheme would be *hideously* slow, but correct even for the exceptionally rare fallback case.
 */
[[gnu::visibility("hidden")]]
IMP
_NSInvocationForwardHook(id receiver, SEL aSel)
{
	Class c;
	bool resolved;
	NSMethodSignature *sig;

	/* class_getMethodImplementation() called us. Defer the whole lookup. */
	if (receiver == nil) {
		/* Heuristically determine which msgSend routine to use. */
		const char *const types = sel_getType_np(aSel);
		if (types != nullptr) {
			NSUInteger size;
			(void)NSTypeEncodingStringMeasure(types, &size, nullptr, nullptr);
			if (size > 16)
				return (IMP)objc_msgSend_stret;
		}

		/* Fallback to default non-stret msgSend. */
		return (IMP)objc_msgSend;
	}

	/* Step #2: Get the instance's class and call the appropriate method. */
	c = object_getClass(receiver);
	resolved = class_isMetaClass(c) ? [(Class)receiver resolveClassMethod:aSel] : [c resolveInstanceMethod:aSel];

	/* If the call returned true and the class does indeed respond to the selector, return its IMP. */
	if (resolved && class_respondsToSelector(c, aSel))
		return class_getMethodImplementation(c, aSel);

	/* Step #2.5: Fall back on -methodSignatureForSelector: to determine the appropriate forwarding trampoline. */
	if ((sig = [(NSObject *)receiver methodSignatureForSelector:aSel]) == nil)
		[(NSObject *)receiver doesNotRecognizeSelector:aSel];

	/* Step #3: Otherwise, hand back the forwarding trampoline. */
	if (NSTypeEncodingStringSizeOf(sig.methodReturnType) <= 16)
		return (IMP)NSInvocationForward;
	else
		return (IMP)NSInvocationForwardStret;
}

#pragma clang diagnostic pop

#pragma mark - Forwarding

[[gnu::visibility("hidden")]]
extern void
NSInvocationForwardHandler(NSInvocationForwardingRegisters *r, bool isStret)
{
	NSObject *__unsafe_unretained target;
	SEL aSel;
	void *stackReturn = nullptr;

	/* Yank our target and selector; if stret, our caller's stack pointer, too. */
	if (isStret) {
		stackReturn = (void *)(uintptr_t)r->GPRegisters[0];
		target = (__bridge NSObject *__unsafe_unretained)(void *)r->GPRegisters[1];
		aSel = (SEL)(uintptr_t)r->GPRegisters[2];
	} else {
		target = (__bridge NSObject *__unsafe_unretained)(void *)r->GPRegisters[0];
		aSel = (SEL)(uintptr_t)r->GPRegisters[1];
	}

	/* Ask the target to describe the call through -methodSignatureForSelector:. */
	NSMethodSignature *sig;
	if ((sig = [target methodSignatureForSelector:aSel]) == nil)
		[target doesNotRecognizeSelector:aSel];

	/* Create the invocation object. */
	NSInvocation *invocation = [[NSInvocation alloc] _initWithMethodSignature:sig forwardingRegisters:r];

	/* Go! */
	[target forwardInvocation:invocation];

	/* Grab the return value. */
	if (isStret) {
		/* If we return a large structure, put the return value back on the caller's original stack. */
		[invocation getReturnValue:stackReturn];
		r->GPRegisters[0] = (unsigned long)(uintptr_t)stackReturn;
	} else {
		unsigned char GPIndex = 0;
		unsigned char SSEIndex = 0;
		NSInvocationClassInfo classInfo;
		unsigned long retVal[2] = { 0 };

		/* Classify the return value, grab it, and place the eightbytes into the proper registers. */
		_NSInvocationClassify(sig.methodReturnType, &classInfo);
		[invocation getReturnValue:retVal];

		for (unsigned char i = 0; i < classInfo.eightbyteCount; ++i) {
			if (classInfo.eightbyteClasses[i] == INTEGER)
				r->returnRegisters[GPIndex++] = retVal[i];
			else
				r->returnRegisters[2 + SSEIndex++] = retVal[i];
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
	/* If we retained our arguments, retain the new and release the old. Otherwise, just assign. */
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
 * saved registers and the caller's stack as their System V homes are computed. When registers is null, the same
 * layout pass runs and the argument buffers simply stay zeroed.
 */
- (instancetype)_initWithMethodSignature:(NSMethodSignature *)methodSignature
		forwardingRegisters:(NSInvocationForwardingRegisters *)registers OBJC_DIRECT
{
	unsigned char GPIndex = 0;
	unsigned char SSEIndex = 0;
	NSUInteger stackOffset = 0;

	/* Retain the method signature. */
	_methodSignature = methodSignature;

	/* Get the return value's type string and classify it. */
	_returnInfo.type = _NSTypeEncodingSkipQualifier(methodSignature.methodReturnType);
	_NSInvocationClassify(_returnInfo.type, &_returnInfo.classInfo);

	/* If we return a value, make some room. Round up to 8 bytes to make register copying easy. */
	if (_returnInfo.classInfo.size != 0)
		_returnInfo.returnBuffer = calloc(1, _NSInvocationAlignUp(_returnInfo.classInfo.size, 8));

	/* Methods returning large structures consume %rdi. */
	if (_returnInfo.classInfo.size > 16)
		++GPIndex;

	/* When created from a forwarded message, harvest self and _cmd after the optional stret slot. */
	if (registers != nullptr) {
		_target = (__bridge id)(void *)registers->GPRegisters[GPIndex];
		_selector = (SEL)registers->GPRegisters[GPIndex + 1];
	}

	/* Get the total number of arguments. If we only have two, no handling of extra arguments is needed. */
	NSUInteger const nArgs = _numberOfArguments = methodSignature.numberOfArguments;
	if (nArgs == 2)
		return self;

	/* Allocate the argument info array. */
	_argumentsInfo = calloc(nArgs - 2, sizeof(*_argumentsInfo));

	/* Reserve room for the object and selector parameters. */
	GPIndex += 2;

	for (NSUInteger i = 2, a = 0; i < nArgs; ++i, ++a) {
		bool isMemory;
		unsigned char needGP;
		unsigned char needSSE;

		/* Get refs to argument info and classification info; store the argument's type and classify it. */
		NSInvocationArgumentInfo *const argInfo = &_argumentsInfo[a];
		NSInvocationClassInfo *const classInfo = &(_argumentsInfo[a].classInfo);
		argInfo->type = _NSTypeEncodingSkipQualifier([methodSignature getArgumentTypeAtIndex:i]);
		/* Clang can retain an array spelling for a parameter adjusted to a pointer. Only the outermost
		 * argument is adjusted; the recursive classifier must still expand arrays inside structures. */
		char const *type = argInfo->type;
		_NSInvocationClassify(*type == '[' ? "^v" : type, classInfo);

		/* If the argument isn't an empty aggregate, allocate space. */
		if (classInfo->size != 0)
			argInfo->bytes = calloc(1, _NSInvocationAlignUp(classInfo->size, 8));
		else
			continue; /* Empty aggregate. Please forward all complaints to your local Stallmanite. */

		/* Compute layout. We are automatically MEMORY if size > 16. */
		isMemory = classInfo->size > 16;
		needGP = needSSE = 0;

		/* Calculate how many registers we'd need. */
		if (isMemory == false)
			for (unsigned char j = 0; j < classInfo->eightbyteCount; ++j)
				classInfo->eightbyteClasses[j] == INTEGER ? ++needGP : ++needSSE;

		/* Store register locations if we have some left over. Otherwise, we're MEMORY; spill to stack. */
		if (isMemory == false && GPIndex + needGP <= 6 && SSEIndex + needSSE <= 8) {
			argInfo->onStack = false;

			/* Each eightbyte is given an index into a register bank. */
			for (unsigned char j = 0; j < classInfo->eightbyteCount; ++j) {
				char *argEightbyte = argInfo->bytes + j * 8;

				if (classInfo->eightbyteClasses[j] == INTEGER) {
					argInfo->eightbyteRegisterIndices[j] = GPIndex++;
					if (registers != nullptr)
						__builtin_memcpy_inline(argEightbyte,
							&registers->GPRegisters[GPIndex - 1], 8);
				} else {
					argInfo->eightbyteRegisterIndices[j] = SSEIndex++;
					if (registers != nullptr)
						__builtin_memcpy_inline(argEightbyte,
							&registers->SSERegisters[SSEIndex - 1], 8);
				}
			}
		} else {
			/* Large arguments are 8-byte aligned on the stack. */
			argInfo->onStack = true;
			stackOffset = _NSInvocationAlignUp(stackOffset, 8);
			argInfo->stackOffset = stackOffset;
			if (registers != nullptr)
				memcpy(argInfo->bytes, registers->stack + stackOffset, classInfo->size);
			stackOffset += _NSInvocationAlignUp(classInfo->size, 8);
		}
	}

	/* Allocate stack space if needed. The stack is always 16-byte aligned on amd64. */
	if ((_invocationFrame.stackSize = _NSInvocationAlignUp(stackOffset, 16)) != 0)
		_invocationFrame.stack = calloc(1, _invocationFrame.stackSize);

	return self;
}

#pragma mark - Helpers

/* Acquire a pointer slot before releasing its predecessor. The source may contain a borrowed pointer into
 * the old value (including a C-string suffix). Block encodings require a heap copy, not objc_retain(). */
[[clang::always_inline]]
static inline void *
_NSInvocationAcquireValue(char const *type, void const *source)
{
	void *value;

	memcpy(&value, source, sizeof(value));
	if (value == nullptr)
		return nullptr;
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
		memcpy(_returnInfo.returnBuffer, &value, sizeof(value));
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
			memcpy(argInfo->bytes, &value, sizeof(value));
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
		memcpy(_returnInfo.returnBuffer, &value, sizeof(value));
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
				memcpy(_argumentsInfo[index - 2].bytes, &value, sizeof(value));
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

	/* New scope, because I'm too lazy to use a different name for GPIndex later on. */
	{
		NSUInteger GPIndex = 0;

		/* If we're returning a large structure, assign our allocated return buffer to %rdi. */
		if (_returnInfo.classInfo.size > 16)
			_invocationFrame.GPRegisters[GPIndex++] = (unsigned long)(uintptr_t)_returnInfo.returnBuffer;

		/* Load in target and selector. */
		_invocationFrame.GPRegisters[GPIndex++] = (unsigned long)(uintptr_t)_target;
		_invocationFrame.GPRegisters[GPIndex++] = (unsigned long)(uintptr_t)(void *)_selector;
	}

	/* For all real arguments in the argument array; place their bytes where they belong. */
	for (NSUInteger i = 0; i < _numberOfArguments - 2; ++i) {
		NSInvocationArgumentInfo *argInfo;
		NSInvocationClassInfo *classInfo;

		argInfo = &_argumentsInfo[i];
		classInfo = &argInfo->classInfo;

		/* If we live on the stack, copy our bytes to our desired stack offset. */
		if (argInfo->onStack == true) {
			memcpy(_invocationFrame.stack + argInfo->stackOffset, argInfo->bytes, classInfo->size);
			continue;
		}

		/*
		 * If we live in registers, copy each eightbyte into its proper spot. eightbyteCount guards against
		 * empty aggregates; we don't need to explicitly check here.
		 * Copying eight bytes indiscriminately works for two reasons: we take care to zero out unused bytes
		 * when assigning arguments into their byte buffers, and these buffers are always 8-byte aligned.
		 * This makes copying, say, 12 byte structures a lot more convenient.
		 */
		for (unsigned char j = 0; j < classInfo->eightbyteCount; ++j) {
			char const *const argEightbyte = argInfo->bytes + j * 8;

			if (classInfo->eightbyteClasses[j] == INTEGER)
				memcpy(&_invocationFrame.GPRegisters[argInfo->eightbyteRegisterIndices[j]],
					argEightbyte, 8);
			else
				memcpy(&_invocationFrame.SSERegisters[argInfo->eightbyteRegisterIndices[j]],
					argEightbyte, 8);
		}
	}

	/* Go! */
	NSInvocationCall(&_invocationFrame);

	/* If we return a single value, or a structure <= 16 bytes, reassemble it from the return banks. */
	if (_returnInfo.classInfo.size <= 16) {
		unsigned char GPIndex = 0;
		unsigned char SSEIndex = 0;
		unsigned long retVal[2] = { 0 };

		for (unsigned char i = 0; i < _returnInfo.classInfo.eightbyteCount; ++i) {
			if (_returnInfo.classInfo.eightbyteClasses[i] == INTEGER)
				retVal[i] = _invocationFrame.returnRegisters[GPIndex++];
			else
				retVal[i] = _invocationFrame.returnRegisters[2 + SSEIndex++];
		}

		memcpy(_returnInfo.returnBuffer, retVal, _returnInfo.classInfo.size);

		/* When arguments are retained, the freshly-produced return value is owned by us too. */
		if (_argumentsRetained == true)
			[self _retainReturnValue];
	}
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

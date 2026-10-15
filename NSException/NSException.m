
/*
 * TODO: this is all kind of ugly. Miscellanous bits and bobs need to be completed.
 */

#import <FoundationPrivate/NSObject/NSObject.h>
#include <objc/objc-exception.h>

#define __USE_GNU

#include <unwind.h>
#include <dlfcn.h>

/* Define raw malloc() because if we fail to allocate memory in here, no exception will save us. */
void *_Nullable malloc(NSUInteger);

static NSUInteger _Atomic callers = 0;
static NSMutex callStack = { 0 };
static NSMutex wait = { 0 };

typedef struct NSUnwindData {
	char **callStackSymbols;
	int *symbolLengths;
	NSUInteger symbolCount;
	NSUInteger symbolCapacity;
} NSUnwindData;

typedef struct NSObjCFrameEntry {
	uintptr_t imp;
	Class cls;
	SEL sel;
} NSObjCFrameEntry;

static thread_local NSObjCFrameEntry *_NSExceptionFrameTable = nullptr;
static thread_local NSUInteger _NSExceptionFrameTableCount = 0;

/*
 * Mirrors of the Class, Method list, and Method structs so we can walk a class's methods without allocating a
 * throwaway array through class_copyMethodList(). Methods within a list are l->size bytes apart.
 */
typedef struct _NSObjCMethod {
	IMP imp;
	SEL selector;
	char const *types;
} _NSObjCMethod;

typedef struct _NSObjCMethodList {
	struct _NSObjCMethodList *next;
	int count;
	char padding[4];
	unsigned long size;
	struct _NSObjCMethod methods[];
} _NSObjCMethodList;

/* Only the methods pointer matters here. Everything before it is effectively padding for our use case. */
typedef struct _NSObjCClass {
	Class isa;
	Class super_class;
	char const *name;
	long version;
	unsigned long info;
	long instance_size;
	void *ivars;
	struct _NSObjCMethodList *methods;
} _NSObjCClass;

#pragma mark - Unwind Helpers

[[clang::always_inline]]
static inline struct _NSObjCMethod *
_NSMethodAtIndex(const _NSObjCMethodList *const l, int const i)
{
	return (_NSObjCMethod *)(uintptr_t)((char const *)l->methods + (unsigned int)i * l->size);
}

static int
_NSObjCFrameEntryCompare(void const *const a, void const *const b)
{
	uintptr_t ai = ((NSObjCFrameEntry const *)a)->imp;
	uintptr_t bi = ((NSObjCFrameEntry const *)b)->imp;

	return (ai > bi) - (ai < bi);
}

/*
 * Build an IMP-sorted index of every Objective-C method. Each class is walked twice, once for its instance methods
 * and again for its class methods in its metaclass. Rather than allocate (and immediately discard) a Method array per
 * class via class_copyMethodList() just to learn a count, we walk the runtime's objc_method_list chains directly. We
 * tally method counts, perform one exact malloc(), then do a fill pass. We free nothing but the scratch class list
 * since we're already a dead man walking.
 *
 * This traversal is deliberately lock-free. The only mutators of a class's method list chain either prepend a fresh
 * node at the head (class_addMethod(), category loading) and never touch existing nodes, or free the whole chain
 * (freeMethodLists() via objc_disposeClassPair) under the runtime lock. If a class is disposed while the task is
 * unwinding to its death... ¯\_(ツ)_/¯
 *
 * The fill pass is bounded by total so a prepend racing between the two passes can never overflow the table.
 */
static void
_NSExceptionBuildFrameTable(void)
{
	NSUInteger total = 0;
	NSUInteger idx = 0;

	/* Get a list of every class which the runtime currently knows about. */
	unsigned int classCount;
	Class *const allClasses = objc_copyClassList(&classCount);

	/* Tally instance and class methods across every class by walking its method lists. */
	for (unsigned int i = 0; i < classCount; ++i) {
		for (int pass = 0; pass < 2; ++pass) {
			Class searchOn = (pass == 0) ? allClasses[i] : object_getClass((id)allClasses[i]);
			_NSObjCMethodList const *methodList = ((__bridge _NSObjCClass *)searchOn)->methods;

			for (; methodList != nullptr; methodList = methodList->next)
				total += (NSUInteger)methodList->count;
		}
	}

	/* Allocate the table now that we know the entry count. */
	NSUInteger totalBytes;
	NSObjCFrameEntry *table;
	if (__builtin_mul_overflow(total, sizeof(*table), &totalBytes))
		abort(); /* If an overflow ever actually happens here, I'll eat my hat. As such, no NSException. */

	table = malloc(totalBytes);
	if (table == nullptr)
		abort();

	/* For all classes and metaclasses, fill in imp, cls, and sel per method. */
	for (unsigned int i = 0; i < classCount; ++i) {
		for (int pass = 0; pass < 2; ++pass) {
			Class searchOn = (pass == 0) ? allClasses[i] : object_getClass((id)allClasses[i]);
			_NSObjCMethodList const *methodList = ((__bridge _NSObjCClass *)searchOn)->methods;

			for (; methodList != nullptr; methodList = methodList->next) {
				for (int j = 0; j < methodList->count; ++j) {
					_NSObjCMethod const *const m = _NSMethodAtIndex(methodList, j);

					/* A lock-free prepend between the two passes must never overflow. */
					if (idx >= total)
						goto filled;

					table[idx].imp = (uintptr_t)(void *)m->imp;
					table[idx].cls = searchOn;
					table[idx].sel = m->selector;
					++idx;
				}
			}
		}
	}

filled:
	/* The scratch class list has served its purpose. */
	free(allClasses);

	/* Sort by IMP so the resolver can binary search by region start. */
	qsort(table, idx, sizeof(*table), _NSObjCFrameEntryCompare);

	/* Publish to this thread's cache. */
	_NSExceptionFrameTable = table;
	_NSExceptionFrameTableCount = idx;
}

/* Map a frame's start address from _Unwind_GetRegionStart() to the Objective-C method that owns it. */
static bool
_NSResolveObjCFrame(uintptr_t regionStart, char const *_Nonnull *const _Nullable className, SEL *const selector,
			bool *const isClassMethod)
{
	NSUInteger lo = 0;
	NSUInteger hi;

	if (_NSExceptionFrameTable == nullptr)
		_NSExceptionBuildFrameTable();

	/* Lower-bound binary search: smallest index with imp >= regionStart. */
	hi = _NSExceptionFrameTableCount;

	while (lo < hi) {
		NSUInteger mid = lo + (hi - lo) / 2;

		if (_NSExceptionFrameTable[mid].imp < regionStart)
			lo = mid + 1;
		else
			hi = mid;
	}

	/* We only want an exact match. */
	if (lo >= _NSExceptionFrameTableCount || _NSExceptionFrameTable[lo].imp != regionStart)
		return false;

	/* Fill out parameters. */
	*className = class_getName(_NSExceptionFrameTable[lo].cls);
	*selector = _NSExceptionFrameTable[lo].sel;
	*isClassMethod = class_isMetaClass(_NSExceptionFrameTable[lo].cls);

	return true;
}

static _Unwind_Reason_Code
_NSExceptionProcess(struct _Unwind_Context *context, void *argument)
{
	char const *className;
	SEL sel;
	bool isClassMethod;
	char *symbol;
	int written;

	/* Collect relevant information. */
	NSUnwindData *const unwindData = (NSUnwindData *)argument;
	void *const pc = (void *)(uintptr_t)_Unwind_GetIP(context);
	uintptr_t const regionStart = (uintptr_t)_Unwind_GetRegionStart(context);
	uintptr_t const offset = (uintptr_t)pc - regionStart;

	/* Resize symbol and symbol length array if needed. */
	if (unwindData->symbolCount >= unwindData->symbolCapacity) {
		char **symbolsTemp;
		int *lengthsTemp;

		if (__builtin_mul_overflow(unwindData->symbolCapacity, 2, &unwindData->symbolCapacity))
			abort();

		symbolsTemp = realloc(unwindData->callStackSymbols, unwindData->symbolCapacity * sizeof(char *));
		if (symbolsTemp == nullptr)
			abort();

		unwindData->callStackSymbols = symbolsTemp;

		lengthsTemp = realloc(unwindData->symbolLengths, unwindData->symbolCapacity * sizeof(int));
		if (lengthsTemp == nullptr)
			abort();

		unwindData->symbolLengths = lengthsTemp;
	}

	Dl_info routineInfo;
	dladdr(pc, &routineInfo);

	/* We assume that sel_getName() will never return null when printing. */
	if (_NSResolveObjCFrame(regionStart, &className, &sel, &isClassMethod))
		written = asprintf(&symbol, "%-4lu %p in %c[%s %s] + %lu (%s)\n", unwindData->symbolCount, pc,
				isClassMethod ? '+' : '-', className, sel_getName(sel), offset, routineInfo.dli_fname);
	else
		written = asprintf(&symbol, "%-4lu %p in %s + %lu (%s)\n", unwindData->symbolCount, pc,
				routineInfo.dli_sname, offset, routineInfo.dli_fname);

	unwindData->callStackSymbols[unwindData->symbolCount] = symbol;
	unwindData->symbolLengths[unwindData->symbolCount++] = written;

	return _URC_NO_REASON;
}

#pragma mark - NSException

@implementation NSException

@synthesize name = _name;
@synthesize reason = _reason;
@synthesize userInfo = _userInfo;

NSExceptionName const NSGenericException = @"NSGenericException";
NSExceptionName const NSRangeException = @"NSRangeException";
NSExceptionName const NSUninitializedObjectUsageException = @"NSUninitializedObjectUsageException";
NSExceptionName const NSUnavailableMethodUsageException = @"NSUnavailableMethodUsageException";
NSExceptionName const NSInvalidArgumentException = @"NSInvalidArgumentException";
NSExceptionName const NSInternalInconsistencyException = @"NSInternalInconsistencyException";
NSExceptionName const NSMallocException = @"NSMallocException";

static unsigned __int128 _NSExceptionHashKey = 0;
static NSUncaughtExceptionHandler *_NSExceptionUserHandler = nil;
static Class _NSExceptionClass = Nil;

#pragma mark User Exception Handler

NSUncaughtExceptionHandler *
NSGetUncaughtExceptionHandler(void)
{
	return _NSExceptionUserHandler;
}

void
NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *h)
{
	_NSExceptionUserHandler = h;
}

#pragma mark Uncaught Exception Handler

void
_NSExceptionObjCHandler(id);

[[noreturn]]
void
_NSExceptionObjCHandler(id object)
{
	/* There's no point in checking if object is an instance of NSException. */
	NSException *exception = (NSException *)object;

	/* If we class_createInstance() an object and then -raise, we end up here. */
	char const *const exceptionName = exception.name.UTF8String;
	if (exceptionName == nil)
		[NSException raise:NSUninitializedObjectUsageException format:@"%s: exception.name was nil.",
			__PRETTY_FUNCTION__];

	/* Keep track of how many threads are currently throwing. */
	OSAtomicAdd(&callers, 1);

	/* 256 entries seems reasonable. We free nothing and let the processing routine realloc as needed. */
	NSUnwindData unwindData = {
		.callStackSymbols = (char **)malloc(256 * sizeof(char *)),
		.symbolLengths = (int *)malloc(256 * sizeof(int)),
		.symbolCount = 0,
		.symbolCapacity = 256
	};

	if (unwindData.callStackSymbols == nullptr || unwindData.symbolLengths == nullptr)
		abort();

	_Unwind_Backtrace(_NSExceptionProcess, &unwindData);

	{
		NSMutexLock(&callStack);

		/* TODO: Someday, implement -lengthOfBytesUsingEncoding:. */
		char *exceptionInfoTitle;
		int written = asprintf(&exceptionInfoTitle,
					"\n" \
					"Terminating application due to uncaught exception '%s'\n" \
					"Reason: '%s'\n" \
					"\n" \
					"Call stack at first @throw:\n",
					exceptionName, exception.reason.UTF8String);

		write(2, exceptionInfoTitle, (NSUInteger)written);

		for (NSUInteger i = 0; i < unwindData.symbolCount; ++i)
			write(2, unwindData.callStackSymbols[i], (NSUInteger)unwindData.symbolLengths[i]);

		NSMutexUnlock(&callStack);
	}

	/*
	 * TODO: come up with a specialized subclass of NSArray to hold the stack trace and lazily convert UTF-8
	 * TODO: strings to UTF-16 NSString objects if requested in the user handler.
	 */
	/* There's no sense in wrapping the @try / @catch block in an @autoreleasepool. */
	if (_NSExceptionUserHandler != nil) {
		@try {
			_NSExceptionUserHandler(exception);
		} @catch (NSException *exception [[maybe_unused]]) {
			abort();
		}
	}

	/*
	 * If we are the last thread to print out stack trace, quit. Otherwise, all other threads wait to give everyone
	 * a chance to print.
	 * TODO: swap this out for a less-sketchy hanging mechanism sometime later.
	 */
	if (OSAtomicSubtract(&callers, 1) == 1)
		abort();
	else {
		NSMutexLock(&wait);
		NSMutexLock(&wait);
	}

	abort();
}

+ (void)initialize
{
	static NSCallOnceState s = {};

	if (self == [NSException class])
		NSCallOnce(&s, ^{
			objc_setUncaughtExceptionHandler(_NSExceptionObjCHandler);
			NSRandomBytes(&_NSExceptionHashKey, sizeof(_NSExceptionHashKey));
			_NSExceptionClass = [NSException class];
		});
}

- (id)copy
{
	return self;
}

#pragma mark Convenience Initializers

+ (void)raise:(NSExceptionName)name format:(NSString *)format, ...
{
	__builtin_va_list arguments;
	__builtin_va_start(arguments, format);

	NSException *obj = class_createInstance(self, 0);
	obj->_name = name;
	obj->_reason = [[NSString alloc] initWithFormat:format arguments:arguments];

	@throw obj;
}

+ (void)raise:(NSExceptionName)name format:(NSString *)format arguments:(__builtin_va_list)arguments
{
	NSException *obj = class_createInstance(self, 0);
	obj->_name = name;
	obj->_reason = [[NSString alloc] initWithFormat:format arguments:arguments];

	@throw obj;
}

+ (instancetype)exceptionWithName:(NSExceptionName)name reason:(nullable NSString *)aReason
		userInfo:(nullable id)userInfo
{
	NSException *obj = class_createInstance(self, 0);

	if (name == nil) {
		obj->_name = NSInvalidArgumentException;
		obj->_reason = [NSString stringWithFormat:@"+[NSException exceptionWithName:reason:userInfo:]: "\
				"name was nil."];
		obj->_userInfo = nil;

		@throw obj;
	}

	obj->_name = [name copy];
	obj->_reason = [aReason copy];
	obj->_userInfo = userInfo;

	return obj;
}

- (instancetype)init
{
	_NSClusterRejectUnavailableMethodInvocation(MethodContext);
	return nil;
}

#pragma mark Methods

- (void)raise NS_NORETURN
{
	@throw self;
}

/*
 * TODO: Contemplate whether or not returning <className: address> name:%@ reason:%@ userInfo:%@ would be more useful.
 */
- (NSString *)description
{
	if (_name == nil)
		_NSRaiseException(MethodContext, NSUninitializedObjectUsageException,
			@"method sent to uninitialized object.");

	return _reason ? (NSString *_Nonnull)_reason : _name;
}

/* TODO: -hash! */

- (bool)isEqual:(id)anObject
{
	if (object_getClass(anObject) == _NSExceptionClass) {
		NSException *otherException = (NSException *)anObject;
		return [_name isEqualToString:otherException.name] && [_reason isEqual:otherException.reason] &&
			[(id<NSObject>)_userInfo isEqual:otherException.userInfo];
	}

	return false;
}

@end

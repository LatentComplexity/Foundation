
#import <FoundationPrivate/NSObject/NSObject.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

[[clang::objc_nonlazy_class]]
@implementation NSObject {
	Class isa;
}

static unsigned __int128 _NSObjectHashKey;

#pragma mark - Protocol

- (NSUInteger)hash
{
	return NSSipHash((void *[]){ (void *)(uintptr_t)self }, sizeof(void *), _NSObjectHashKey);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%s: %p>", object_getClassName(self), (void *)(uintptr_t)self];
}

- (Class)class
{
	return object_getClass(self);
}

- (Class)superclass
{
	return class_getSuperclass(object_getClass(self));
}

- (bool)isProxy
{
	return false;
}

- (bool)isEqual:(nullable id)anObject
{
	return (uintptr_t)self == (uintptr_t)anObject;
}

- (instancetype)self
{
	return self;
}

- (bool)isKindOfClass:(Class)aClass
{
	for (Class i = object_getClass(self); i != nil; i = class_getSuperclass(i))
		if (i == aClass)
			return true;

	return false;
}

- (bool)isMemberOfClass:(Class)aClass
{
	return object_getClass(self) == aClass;
}

- (bool)conformsToProtocol:(Protocol *)aProtocol
{
	return class_conformsToProtocol(object_getClass(self), aProtocol);
}

- (bool)respondsToSelector:(SEL)aSelector
{
	return class_respondsToSelector(object_getClass(self), aSelector);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-strict"

- (id)performSelector:(SEL)aSelector
{
	if (aSelector == nullptr)
		[self doesNotRecognizeSelector:aSelector];

	return ((id (*)(id, SEL))objc_msgSend)(self, aSelector);
}

- (id)performSelector:(SEL)aSelector withObject:(id)firstObject
{
	if (aSelector == nullptr)
		[self doesNotRecognizeSelector:aSelector];

	return ((id (*)(id, SEL, id))objc_msgSend)(self, aSelector, firstObject);
}

- (id)performSelector:(SEL)aSelector withObject:(id)firstObject withObject:(id)secondObject
{
	if (aSelector == nullptr)
		[self doesNotRecognizeSelector:aSelector];

	return ((id (*)(id, SEL, id, id))objc_msgSend)(self, aSelector, firstObject, secondObject);
}

#pragma clang diagnostic pop

#pragma mark - Class Methods

extern bool
objc_create_block_classes_as_subclasses_of(Class);

+ (void)load
{
	static NSCallOnceState s = {};

	NSCallOnce(&s, ^{
		objc_create_block_classes_as_subclasses_of(self);
		NSRandomBytes(&_NSObjectHashKey, sizeof(_NSObjectHashKey));
	});
}

+ (void)initialize
{
}

+ (instancetype)alloc
{
	return class_createInstance(self, 0); 
}

+ (void)dealloc
{
	[NSException raise:NSUnavailableMethodUsageException
		format:@"+[%s dealloc]: cannot deallocate an instance of a metaclass.", class_getName(self)];
}

+ (instancetype)new
{
	return [[self alloc] init];
}

+ (Class)class
{
	return self;
}

+ (Class)superclass
{
	return class_getSuperclass(self);
}

+ (bool)isSubclassOfClass:(Class)aClass
{
	for (Class i = self; i != nil; i = class_getSuperclass(self))
		if (i == aClass)
			return true;

	return false;
}

+ (bool)conformsToProtocol:(Protocol *)aProtocol
{
	return class_conformsToProtocol(self, aProtocol);	
}

+ (bool)instancesRespondToSelector:(SEL)aSelector
{
	return class_respondsToSelector(self, aSelector);
}

+ (IMP)instanceMethodForSelector:(SEL)aSelector
{
	return class_getMethodImplementation(self, aSelector);
}

+ (bool)resolveClassMethod:(SEL)aSelector
{
	return false;
}

+ (bool)resolveInstanceMethod:(SEL)aSelector
{
	return false;
}

+ (nullable NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)aSelector
{
	Method m;

	if ((m = class_getInstanceMethod(self, aSelector)) == nullptr)
		return nil;

	return [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
}

+ (NSString *)description
{
	return (id)NSStringFromClass(self);
}

#pragma mark - Instance Methods

- (instancetype)init
{
	return self;
}

- (void)dealloc
{
	object_dispose(self);
}

- (IMP)methodForSelector:(SEL)aSelector
{
	return class_getMethodImplementation(object_getClass(self), aSelector);
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	Method const m = class_getInstanceMethod(object_getClass(self), aSelector);

	if (m == nullptr)
		return nil;

	return [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
	return nil;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	[self doesNotRecognizeSelector:[anInvocation selector]];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
	char const *className;
	char const *selName;
	char sigil;

	className = object_getClassName(self);

	if (aSelector == nullptr) {
		sigil = '-';
		selName = "(null selector)";
	} else {
		sigil = class_getClassMethod([self class], aSelector) != nullptr ? '+' : '-';
		selName = sel_getName(aSelector);
	}

	[NSException raise:NSInvalidArgumentException format:@"%c[%s %s]: unrecognized selector sent to instance %p.",
		sigil, className, selName, (void *)(uintptr_t)self];
}

+ (void)_TrivialAllocInit
{
}

@end


#import <Foundation/NSObjCRuntime.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NSObject

@property (nonatomic, readonly) NSUInteger hash;
@property (nonatomic, readonly) NSString *description;
@property (nonatomic, readonly) Class class;
@property (nonatomic, readonly) Class superclass;
@property (nonatomic, readonly) bool isProxy;

- (bool)isEqual:(nullable id)anObject;

- (instancetype)self;

- (bool)isKindOfClass:(Class)aClass;

- (bool)isMemberOfClass:(Class)aClass;

- (bool)conformsToProtocol:(Protocol *)aProtocol;

- (bool)respondsToSelector:(SEL)aSelector;

- (id)performSelector:(SEL)aSelector;

- (id)performSelector:(SEL)aSelector withObject:(nullable id)firstObject;

- (id)performSelector:(SEL)aSelector withObject:(nullable id)firstObject withObject:(nullable id)secondObject;

@end

@protocol NSCopying
- (id)copy;
@end

@protocol NSMutableCopying
- (id)mutableCopy;
@end

@class NSMethodSignature, NSInvocation;

[[clang::objc_root_class]]
@interface NSObject <NSObject>

+ (void)load;

+ (void)initialize;

+ (instancetype)alloc;

+ (instancetype)new;

+ (Class)class;

+ (Class)superclass;

+ (bool)isSubclassOfClass:(Class)aClass;

+ (bool)conformsToProtocol:(Protocol *)aProtocol;

+ (bool)instancesRespondToSelector:(SEL)aSelector;

+ (IMP)instanceMethodForSelector:(SEL)aSelector;

+ (bool)resolveClassMethod:(SEL)aSelector;

+ (bool)resolveInstanceMethod:(SEL)aSelector;

+ (nullable NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)aSelector;

+ (NSString *)description;

- (instancetype)init NS_DESIGNATED_INITIALIZER;

- (void)dealloc;

- (IMP)methodForSelector:(SEL)aSelector;

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;

- (id)forwardingTargetForSelector:(SEL)aSelector;

- (void)forwardInvocation:(NSInvocation *)anInvocation;

- (void)doesNotRecognizeSelector:(SEL)aSelector;

@end

NS_ASSUME_NONNULL_END

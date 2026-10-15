
#import <Foundation/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

@class NSMethodSignature;

[[clang::objc_subclassing_restricted]]
@interface NSInvocation : NSObject

@property (nonatomic, readonly) NSMethodSignature *methodSignature;
@property (nonatomic, nullable, unsafe_unretained) id target;
@property (nonatomic) SEL selector;
@property (nonatomic, readonly) bool argumentsRetained;

+ (instancetype)invocationWithMethodSignature:(NSMethodSignature *)methodSignature;

- (instancetype)init NS_UNAVAILABLE;

- (void)setReturnValue:(void *)returnValueLocation;

- (void)getReturnValue:(void *)returnValueLocation;

- (void)setArgument:(void *)argumentLocation atIndex:(NSUInteger)index;

- (void)getArgument:(void *)argumentLocation atIndex:(NSUInteger)index;

- (void)retainArguments;

- (void)invoke;

- (void)invokeWithTarget:(nullable id)aTarget;

- (void)invokeUsingIMP:(IMP)anIMP;

@end

NS_ASSUME_NONNULL_END


#import <Foundation/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

[[clang::objc_subclassing_restricted]]
@interface NSMethodSignature : NSObject

@property (nonatomic, readonly) char const *methodReturnType NS_RETURNS_INNER_POINTER;
@property (nonatomic, readonly) NSUInteger methodReturnLength;
@property (nonatomic, readonly) NSUInteger numberOfArguments;
@property (nonatomic, readonly) NSUInteger frameLength;

+ (instancetype)signatureWithObjCTypes:(char const *)types;

- (instancetype)init NS_UNAVAILABLE;

- (char const *)getArgumentTypeAtIndex:(NSUInteger)index NS_RETURNS_INNER_POINTER;

- (bool)isOneway;

- (bool)isEqualToMethodSignature:(NSMethodSignature *)aMethodSignature;

@end

NS_ASSUME_NONNULL_END

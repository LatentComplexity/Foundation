
#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTaggedConstantString : NSString

enum : uintptr_t {
	NSTaggedConstantStringClass = 0b100
};

+ (instancetype)_stringWithBytes:(char const *)bytes length:(NSUInteger)length OBJC_DIRECT;

@end

NS_ASSUME_NONNULL_END

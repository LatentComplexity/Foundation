
#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSASCIIString : NSString

- (nullable instancetype)_initWithBytes:(char const *)bytes length:(NSUInteger)length OBJC_DIRECT;

- (nullable instancetype)_initWithBytesNoCopy:(char *)bytes length:(NSUInteger)length
			freeWhenDone:(bool)freeBuffer OBJC_DIRECT;

- (nullable instancetype)_initWithNullTerminatedBytesNoCopy:(char *)bytes length:(NSUInteger)length
			freeWhenDone:(bool)freeBuffer OBJC_DIRECT;

@end

NS_ASSUME_NONNULL_END

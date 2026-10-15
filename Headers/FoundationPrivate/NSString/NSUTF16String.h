
#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSUTF16String : NSString

- (nullable instancetype)initWithBytes:(void const *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding NS_UNAVAILABLE;

- (nullable instancetype)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding freeWhenDone:(bool)freeBuffer NS_UNAVAILABLE;

- (instancetype)initWithCharacters:(unichar const *)characters length:(NSUInteger)length NS_UNAVAILABLE;

- (instancetype)initWithCharactersNoCopy:(unichar *)characters length:(NSUInteger)length
		freeWhenDone:(bool)freeBuffer NS_UNAVAILABLE;

- (nullable instancetype)_initWithBytes:(char const *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding OBJC_DIRECT;

- (nullable instancetype)_initWithBytesNoCopy:(char *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding freeWhenDone:(bool)freeBuffer OBJC_DIRECT;

- (instancetype)_initWithCharacters:(unichar const *)characters length:(NSUInteger)length OBJC_DIRECT;

- (instancetype)_initWithCharactersNoCopy:(unichar *)characters length:(NSUInteger)length
			freeWhenDone:(bool)freeBuffer OBJC_DIRECT;

@end

NS_ASSUME_NONNULL_END

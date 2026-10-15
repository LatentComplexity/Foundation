
/*
 * TODO: Everything here must go once I find the time to reinvent libicu and bake in everything from scratch.
 * TODO: NSString exists in this sorry state only to appease NSException's public API surface and a few other things.
 * TODO: Currently, one should consider NSString as an implementation detail.
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>

NS_ASSUME_NONNULL_BEGIN

typedef unsigned short unichar;

typedef enum NSStringEncoding : unsigned char {
	NSASCIIStringEncoding = 1,
	NSUTF8StringEncoding = 2,
	NSUTF16StringEncoding = 3,
	NSUTF16BigEndianStringEncoding = 4,
	NSUTF16LittleEndianStringEncoding = 5,
//	NSUTF32StringEncoding = 6,
//	NSUTF32BigEndianStringEncoding = 7,
//	NSUTF32LittleEndianStringEncoding = 8
} NSStringEncoding;

typedef enum NS8BitStringEncoding : unsigned char {
	NS8BitASCIIStringEncoding = NSASCIIStringEncoding,
	NS8BitUTF8StringEncoding = NSUTF8StringEncoding
} NS8BitStringEncoding;

@interface NSString : NSObject <NSCopying>

@property (nonatomic, readonly) NSUInteger length;
@property (nullable, nonatomic, readonly) char const *UTF8String NS_RETURNS_INNER_POINTER;

+ (instancetype)string;

+ (instancetype)stringWithString:(NSString *)aString;

+ (nullable instancetype)stringWithCString:(char const *)cString encoding:(NS8BitStringEncoding)encoding;

+ (nullable instancetype)stringWithUTF8String:(char const *)utf8String NS_FORMAT_ARGUMENT(1);

+ (instancetype)stringWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

+ (instancetype)stringWithCharacters:(unichar const *)characters length:(NSUInteger)length;

- (instancetype)init NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithString:(NSString *)aString;

- (nullable instancetype)initWithCString:(char const *)nullTerminatedCString encoding:(NS8BitStringEncoding)encoding;

- (nullable instancetype)initWithUTF8String:(char const *)utf8String NS_FORMAT_ARGUMENT(1);

- (instancetype)initWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

- (instancetype)initWithFormat:(NSString *)format arguments:(__builtin_va_list)arguments NS_FORMAT_FUNCTION(1, 0);

- (nullable instancetype)initWithBytes:(void const *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding;

- (nullable instancetype)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length
			encoding:(NSStringEncoding)encoding freeWhenDone:(bool)freeBuffer;

- (instancetype)initWithCharacters:(unichar const *)characters length:(NSUInteger)length;

- (instancetype)initWithCharactersNoCopy:(unichar *)characters length:(NSUInteger)length freeWhenDone:(bool)freeBuffer;

- (unichar)characterAtIndex:(NSUInteger)index;

- (void)getCharacters:(unichar *)buffer range:(NSRange)range;

- (nullable char const *)cStringUsingEncoding:(NS8BitStringEncoding)encoding NS_RETURNS_INNER_POINTER;

- (bool)isEqualToString:(NSString *)aString;

@end

NS_ASSUME_NONNULL_END

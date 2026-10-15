
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum NSStringBuilderEncoding : unsigned char {
	NSStringBuilderEncodingUTF8,
	NSStringBuilderEncodingUTF16
} NSStringBuilderEncoding;

/*
 * length is an element count, not a byte count. isASCII is true when every emitted code point was <= 0x7F. data is
 * malloc'd and owned by the caller. Free it, or hand it off through a NoCopy initializer.
 */
typedef struct NSStringBuilderResult {
	union {
		char *utf8;
		unichar *utf16;
	} data;
	NSUInteger length;
	bool isASCII;
	NSStringBuilderEncoding encoding;
	char padding[6];
} NSStringBuilderResult;

NSStringBuilderResult
NSStringBuilder(NSStringBuilderEncoding encoding, NSString *format, __builtin_va_list arguments);

NS_ASSUME_NONNULL_END

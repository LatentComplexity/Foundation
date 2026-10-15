
#import <Foundation/NSObjCRuntime.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum NSDoubleKind : unsigned char {
	NSDoubleKindRegular = 0,
	NSDoubleKindZero,
	NSDoubleKindInfinity,
	NSDoubleKindNaN
} NSDecimalDoubleKind;

typedef struct NSDecimalDouble {
	unsigned long significand;
	int exp10;
	NSDecimalDoubleKind kind;
	bool isNegative;
	unsigned char padding[2];
} NSDecimalDouble;

void
NSDoubleToDecimal(double, NSDecimalDouble *);

NS_ASSUME_NONNULL_END

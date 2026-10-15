
#import <Foundation/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSValue : NSObject <NSCopying>

@property (nonatomic, readonly) char const *objCType NS_RETURNS_INNER_POINTER;
@property (nullable, nonatomic, readonly) void *pointerValue;

+ (instancetype)valueWithBytes:(void const *)value objCType:(char const *)type;

+ (instancetype)valueWithPointer:(nullable void const *)pointer;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithBytes:(void const *)value objCType:(char const *)type NS_DESIGNATED_INITIALIZER;

- (void)getValue:(void *)value size:(NSUInteger)size;

- (bool)isEqualToValue:(NSValue *)aValue;

@end

@interface NSNumber : NSValue

@property (nonatomic, readonly) char charValue;
@property (nonatomic, readonly) unsigned char unsignedCharValue;
@property (nonatomic, readonly) short shortValue;
@property (nonatomic, readonly) unsigned short unsignedShortValue;
@property (nonatomic, readonly) int intValue;
@property (nonatomic, readonly) unsigned int unsignedIntValue;
@property (nonatomic, readonly) long longValue;
@property (nonatomic, readonly) unsigned long unsignedLongValue;
@property (nonatomic, readonly) long long longLongValue;
@property (nonatomic, readonly) unsigned long long unsignedLongLongValue;
@property (nonatomic, readonly) NSInteger integerValue;
@property (nonatomic, readonly) NSUInteger unsignedIntegerValue;
@property (nonatomic, readonly) bool boolValue;
@property (nonatomic, readonly) float floatValue;
@property (nonatomic, readonly) double doubleValue;

+ (instancetype)numberWithChar:(char)value;

+ (instancetype)numberWithUnsignedChar:(unsigned char)value;

+ (instancetype)numberWithShort:(short)value;

+ (instancetype)numberWithUnsignedShort:(unsigned short)value;

+ (instancetype)numberWithInt:(int)value;

+ (instancetype)numberWithUnsignedInt:(unsigned int)value;

+ (instancetype)numberWithLong:(long)value;

+ (instancetype)numberWithUnsignedLong:(unsigned long)value;

+ (instancetype)numberWithLongLong:(long long)value;

+ (instancetype)numberWithUnsignedLongLong:(unsigned long long)value;

+ (instancetype)numberWithInteger:(NSInteger)value;

+ (instancetype)numberWithUnsignedInteger:(NSUInteger)value;

+ (instancetype)numberWithBool:(bool)value;

+ (instancetype)numberWithFloat:(float)value;

+ (instancetype)numberWithDouble:(double)value;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithChar:(char)value;

- (instancetype)initWithUnsignedChar:(unsigned char)value;

- (instancetype)initWithShort:(short)value;

- (instancetype)initWithUnsignedShort:(unsigned short)value;

- (instancetype)initWithInt:(int)value;

- (instancetype)initWithUnsignedInt:(unsigned int)value;

- (instancetype)initWithLong:(long)value;

- (instancetype)initWithUnsignedLong:(unsigned long)value;

- (instancetype)initWithLongLong:(long long)value;

- (instancetype)initWithUnsignedLongLong:(unsigned long long)value;

- (instancetype)initWithInteger:(NSInteger)value;

- (instancetype)initWithUnsignedInteger:(NSUInteger)value;

- (instancetype)initWithBool:(bool)value;

- (instancetype)initWithFloat:(float)value;

- (instancetype)initWithDouble:(double)value;

- (bool)isEqualToNumber:(NSNumber *)aNumber;

- (NSComparisonResult)compare:(NSNumber *)otherNumber;

@end

NS_ASSUME_NONNULL_END

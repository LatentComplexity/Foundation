
#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Data Search Options

typedef enum NS_OPTIONS_ENUM_ATTR NSDataSearchOptions : NSUInteger {
	NSDataSearchDefault = 0UL,
	NSDataSearchBackwards = 1UL << 0,
	NSDataSearchAnchored = 1UL << 1
} NSDataSearchOptions;

#pragma mark - Immutable Data

@interface NSData : NSObject <NSCopying, NSMutableCopying>

@property (nonatomic, readonly) void const *bytes NS_RETURNS_INNER_POINTER;
@property (nonatomic, readonly) NSUInteger count;

+ (instancetype)data;

+ (instancetype)dataWithData:(NSData *)data;

+ (instancetype)dataWithBytes:(void const *)bytes count:(NSUInteger)count;

+ (instancetype)dataWithBytesNoCopy:(void *)bytes count:(NSUInteger)count;

+ (instancetype)dataWithBytesNoCopy:(void *)bytes count:(NSUInteger)count freeWhenDone:(bool)freeBuffer;

- (instancetype)initWithData:(NSData *)data;

- (instancetype)initWithBytes:(void const *)bytes count:(NSUInteger)count;

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count;

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count freeWhenDone:(bool)freeBuffer;

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count
		deallocator:(nullable void (^)(void *, NSUInteger))deallocator;

- (NSData *)subdataWithRange:(NSRange)range;

- (void)getBytes:(void *)buffer count:(NSUInteger)count;

- (void)getBytes:(void *)buffer range:(NSRange)range;

- (void)enumerateByteRangesUsingBlock:(void (NS_NOESCAPE ^)(void const *, NSRange, bool *))block;

- (NSRange)rangeOfData:(NSData *)dataToFind options:(NSDataSearchOptions)searchOptions range:(NSRange)searchRange;

- (bool)isEqualToData:(NSData *)otherData;

@end

#pragma mark - Mutable Data

@interface NSMutableData : NSData

@property (nonatomic, readonly) void *mutableBytes NS_RETURNS_INNER_POINTER;
@property (nonatomic) NSUInteger count;

+ (instancetype)dataWithCapacity:(NSUInteger)capacity;

+ (instancetype)dataWithCount:(NSUInteger)count;

- (instancetype)initWithCapacity:(NSUInteger)capacity;

- (instancetype)initWithCount:(NSUInteger)count;

- (void)increaseCountBy:(NSUInteger)extraCount;

- (void)appendBytes:(void const *)bytes count:(NSUInteger)count;

- (void)appendData:(NSData *)other;

- (void)replaceBytesInRange:(NSRange)range withBytes:(void const *)bytes;

- (void)replaceBytesInRange:(NSRange)range withBytes:(nullable void const *)bytes count:(NSUInteger)count;

- (void)resetBytesInRange:(NSRange)range;

- (void)setData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END

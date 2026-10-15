
#import <Foundation/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

typedef unsigned _BitInt(128) UUID_t;

[[clang::objc_subclassing_restricted]]
@interface NSUUID : NSObject <NSCopying>

@property (nonatomic, readonly, copy) NSString *UUIDString;

+ (instancetype)UUID;

+ (nullable instancetype)UUIDWithUUIDString:(NSString *)string;

+ (instancetype)UUIDWithUUIDBytes:(UUID_t const)bytes;

- (instancetype)init NS_UNAVAILABLE;

- (void)getUUIDBytes:(UUID_t *)uuidBytes;

- (bool)isEqualToUUID:(NSUUID *)otherUUID;

- (NSComparisonResult)compare:(NSUUID *)otherUUID;

@end

NS_ASSUME_NONNULL_END

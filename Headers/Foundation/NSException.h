
#import <Foundation/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

extern NSExceptionName const NSGenericException;
extern NSExceptionName const NSRangeException;
extern NSExceptionName const NSUninitializedObjectUsageException;
extern NSExceptionName const NSUnavailableMethodUsageException;
extern NSExceptionName const NSInvalidArgumentException;
extern NSExceptionName const NSInternalInconsistencyException;
extern NSExceptionName const NSMallocException;

[[clang::objc_exception]]
[[clang::objc_subclassing_restricted]]
@interface NSException : NSObject <NSCopying>

@property (nonnull, nonatomic, readonly, copy) NSExceptionName name;
@property (nullable, nonatomic, readonly, copy) NSString *reason;
@property (nullable, nonatomic, readonly, strong) id userInfo;

+ (void)raise:(NSExceptionName)name format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3) NS_NORETURN;

+ (void)raise:(NSExceptionName)name format:(NSString *)format
		arguments:(__builtin_va_list)arguments NS_FORMAT_FUNCTION(2, 0) NS_NORETURN;

+ (instancetype)exceptionWithName:(NSExceptionName)name reason:(nullable NSString *)aReason
		userInfo:(nullable id)userInfo;

- (instancetype)init NS_UNAVAILABLE;

- (void)raise NS_NORETURN;

@end

#pragma mark - User Exception Handler

typedef void NSUncaughtExceptionHandler(NSException *exception);

NSUncaughtExceptionHandler *_Nullable
NSGetUncaughtExceptionHandler(void);

void
NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *_Nullable);

NS_ASSUME_NONNULL_END

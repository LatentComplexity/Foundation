
#import <Foundation/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum NSCollectionChangeType : NSUInteger {
	NSCollectionChangeInsert = 0,
	NSCollectionChangeRemove = 1
} NSCollectionChangeType;

[[clang::objc_subclassing_restricted]]
@interface NSOrderedCollectionChange<ObjectType> : NSObject

@property (nullable, nonatomic, readonly) ObjectType object;
@property (nonatomic, readonly) NSCollectionChangeType changeType;
@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, readonly) NSUInteger associatedIndex;

+ (NSOrderedCollectionChange<ObjectType> *)changeWithObject:(nullable ObjectType)anObject
		type:(NSCollectionChangeType)type index:(NSUInteger)index;

+ (NSOrderedCollectionChange<ObjectType> *)changeWithObject:(nullable ObjectType)anObject
		type:(NSCollectionChangeType)type index:(NSUInteger)index associatedIndex:(NSUInteger)associatedIndex;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

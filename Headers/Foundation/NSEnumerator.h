
#import <Foundation/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct NSFastEnumerationState {
	unsigned long state;
	id __unsafe_unretained _Nullable *_Nullable itemsPtr;
	unsigned long *_Nullable mutationsPtr;
	unsigned long extra[5];
} NSFastEnumerationState;

@protocol NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity;

@end

@class NSArray<ObjectType>;

@interface NSEnumerator<ObjectType> : NSObject <NSFastEnumeration>

@property (nonatomic, readonly, copy) NSArray<ObjectType> *allObjects;

- (instancetype)init NS_UNAVAILABLE;

- (nullable ObjectType)nextObject;

@end

NS_ASSUME_NONNULL_END

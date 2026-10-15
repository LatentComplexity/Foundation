
#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSEnumerator.h>

NS_ASSUME_NONNULL_BEGIN

@class NSIndexSet;

#pragma mark - Immutable Array

@interface NSArray<__covariant ObjectType> : NSObject <NSCopying, NSMutableCopying, NSFastEnumeration>

@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, nullable, readonly) ObjectType firstObject;
@property (nonatomic, nullable, readonly) ObjectType lastObject;

+ (instancetype)array;

+ (instancetype)arrayWithArray:(NSArray<ObjectType> *)array;

+ (instancetype)arrayWithObject:(ObjectType)anObject;

+ (instancetype)arrayWithObjects:(ObjectType __unsafe_unretained _Nonnull const [_Nonnull])objects
		count:(NSUInteger)count;

+ (instancetype)arrayWithObjects:(ObjectType)firstObject, ... NS_REQUIRES_NIL_TERMINATION;

- (instancetype)initWithArray:(NSArray<ObjectType> *)array;

- (instancetype)initWithArray:(NSArray<ObjectType> *)array copyItems:(bool)shouldCopy;

- (instancetype)initWithObjects:(ObjectType __unsafe_unretained _Nonnull const [_Nonnull])objects
		count:(NSUInteger)count NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithObjects:(ObjectType)firstObject, ... NS_REQUIRES_NIL_TERMINATION;

- (NSArray<ObjectType> *)arrayByAddingObject:(ObjectType)anObject;

- (NSArray<ObjectType> *)arrayByAddingObjectsFromArray:(NSArray<ObjectType> *)otherArray;

- (NSArray<ObjectType> *)subarrayWithRange:(NSRange)range;

- (NSArray<ObjectType> *)objectsAtIndexes:(NSIndexSet *)indexSet;

- (ObjectType)objectAtIndexedSubscript:(NSUInteger)index;

- (void)getObjects:(ObjectType __unsafe_unretained _Nonnull [_Nonnull])objects range:(NSRange)range;

- (void)makeObjectsPerformSelector:(SEL)aSelector;

- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(nullable id)anObject;

- (NSUInteger)indexOfObject:(ObjectType)anObject;

- (NSUInteger)indexOfObject:(ObjectType)anObject inRange:(NSRange)range;

- (NSUInteger)indexOfObjectIdenticalTo:(ObjectType)anObject;

- (NSUInteger)indexOfObjectIdenticalTo:(ObjectType)anObject inRange:(NSRange)range;

- (NSUInteger)indexOfObjectPassingTest:(bool (NS_NOESCAPE ^)(ObjectType, NSUInteger, bool *))predicate;

- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(ObjectType, NSUInteger, bool *))predicate;

- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(ObjectType, NSUInteger, bool *))predicate;

- (NSIndexSet *)indexesOfObjectsPassingTest:(bool (NS_NOESCAPE ^)(ObjectType, NSUInteger, bool *))predicate;

- (NSIndexSet *)indexesOfObjectsWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(ObjectType, NSUInteger, bool *))predicate;

- (NSIndexSet *)indexesOfObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(ObjectType, NSUInteger, bool *))predicate;

- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(ObjectType, NSUInteger, bool *))block;

- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(ObjectType, NSUInteger, bool *))block;

- (void)enumerateObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(ObjectType, NSUInteger, bool *))block;

/* TODO: -firstObjectCommonWithArray:. */

- (bool)containsObject:(ObjectType)anObject;

- (bool)isEqualToArray:(NSArray<ObjectType> *)otherArray;

- (NSEnumerator<ObjectType> *)objectEnumerator;

- (NSEnumerator<ObjectType> *)reverseObjectEnumerator;

@end

#pragma mark - Mutable Array

@interface NSMutableArray<ObjectType> : NSArray<ObjectType>

+ (instancetype)arrayWithCapacity:(NSUInteger)numItems;

- (instancetype)initWithCapacity:(NSUInteger)numItems NS_DESIGNATED_INITIALIZER;

- (void)addObject:(ObjectType)anObject;

- (void)addObjectsFromArray:(NSArray *)otherArray;

- (void)insertObject:(ObjectType)anObject atIndex:(NSUInteger)index;

- (void)insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexes;

- (void)exchangeObjectAtIndex:(NSUInteger)firstIndex withObjectAtIndex:(NSUInteger)secondIndex;

- (void)removeObject:(ObjectType)anObject;

- (void)removeObject:(ObjectType)anObject inRange:(NSRange)range;

- (void)removeObjectIdenticalTo:(ObjectType)anObject;

- (void)removeObjectIdenticalTo:(ObjectType)anObject inRange:(NSRange)range;

- (void)removeObjectAtIndex:(NSUInteger)index;

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes;

- (void)removeObjectsInRange:(NSRange)range;

- (void)removeObjectsInArray:(NSArray *)otherArray;

- (void)removeLastObject;

- (void)removeAllObjects;

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(ObjectType)anObject;

- (void)replaceObjectsAtIndexes:(NSIndexSet *)indexes withObjects:(NSArray *)objects;

- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray *)otherArray;

- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray *)otherArray range:(NSRange)otherRange;

- (void)setObject:(ObjectType)anObject atIndexedSubscript:(NSUInteger)index;

- (void)setArray:(NSArray *)otherArray;

@end

NS_ASSUME_NONNULL_END

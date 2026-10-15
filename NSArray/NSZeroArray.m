
#import <FoundationPrivate/NSArray/NSArray.h>

@implementation NSZeroArray

- (id)mutableCopy
{
	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:NSArrayBufferCreate(0)];
}

- (NSUInteger)count
{
	return 0;
}

- (nullable id)firstObject
{
	return nil;
}

- (nullable id)lastObject
{
	return nil;
}

- (NSArray *)arrayByAddingObject:(id)anObject
{
	_NSRequireNonnil(anObject);

	return [[NSSingleEntryArray alloc] _initWithObject:anObject];
}

- (NSArray *)arrayByAddingObjectsFromArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	/* Technically speaking, we should check if otherArray.count is valid. Eh. Whatever. */
	return [otherArray copy];
}

- (NSArray *)subarrayWithRange:(NSRange)range
{
	if (range.location == 0 && range.length == 0)
		return self;

	_NSRangeWithinUpperBound(range, (NSUInteger)0);

	return nil;
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	Class const c = object_getClass(indexSet);

	if (c == _NSZeroIndexSetClass ||
	    (c == _NSMutableInlineIndexSetClass && ((__bridge NSMutableInlineIndexSetLayout *)indexSet)->count == 0))
		return _NSZeroArrayInstance;

	_NSRaiseException(MethodContext, NSInvalidArgumentException, @"index set extends beyond array bounds.");
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	_NSArrayRequireIndexWithinBounds(index, 0);
	return nil;
}

- (void)getObjects:(id _Nonnull __unsafe_unretained [_Nonnull])objects range:(NSRange)range
{
	_NSRequireNonnullptr(objects);

	if (range.location == 0 && range.length == 0)
		return;

	_NSRangeWithinUpperBound(range, (NSUInteger)0);
}

/* -performSelector: in NSObject catches null selectors in other subclasses, but here we check ourselves. */
- (void)makeObjectsPerformSelector:(SEL)aSelector
{
	_NSRequireNonnullptr(aSelector);
}

- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(nullable id)anObject
{
	_NSRequireNonnullptr(aSelector);
}

- (NSUInteger)indexOfObject:(id)anObject
{
	return NSNotFound;
}

- (NSUInteger)indexOfObject:(id)anObject inRange:(NSRange)range
{
	if (range.location == 0 && range.length == 0)
		return NSNotFound;

	_NSRangeWithinUpperBound(range, (NSUInteger)0);

	return NSNotFound;
}

- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject
{
	return NSNotFound;
}

- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)range
{
	if (range.location == 0 && range.length == 0)
		return NSNotFound;

	_NSRangeWithinUpperBound(range, (NSUInteger)0);

	return NSNotFound;
}

- (NSUInteger)indexOfObjectPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return NSNotFound;
}

- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return NSNotFound;
}

- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	Class const c = object_getClass(indexSet);
	if (c == _NSZeroIndexSetClass ||
	    (c == _NSMutableInlineIndexSetClass && ((__bridge NSMutableInlineIndexSetLayout *)indexSet)->count == 0))
		return NSNotFound;

	_NSRaiseException(MethodContext, NSInvalidArgumentException, @"index set extends beyond array bounds.");
}

- (NSIndexSet *)indexesOfObjectsPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSZeroIndexSetInstance;
}

- (NSIndexSet *)indexesOfObjectsWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSZeroIndexSetInstance;
}

- (NSIndexSet *)indexesOfObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	Class const c = object_getClass(indexSet);
	if (c == _NSZeroIndexSetClass ||
	    (c == _NSMutableInlineIndexSetClass && ((__bridge NSMutableInlineIndexSetLayout *)indexSet)->count == 0))
		return _NSZeroIndexSetInstance;

	_NSRaiseException(MethodContext, NSInvalidArgumentException, @"index set extends beyond array bounds.");
}

- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	return;
}

- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	return;
}

- (void)enumerateObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	Class const c = object_getClass(indexSet);
	if (c == _NSZeroIndexSetClass ||
	    (c == _NSMutableInlineIndexSetClass && ((__bridge NSMutableInlineIndexSetLayout *)indexSet)->count == 0))
		return;

	_NSRaiseException(MethodContext, NSInvalidArgumentException, @"index set extends beyond array bounds.");
}

- (bool)containsObject:(id)anObject
{
	return false;
}

- (NSUInteger)hash
{
	return _NSZeroArrayHash;
}

- (bool)isEqualToArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	/* All zero-length arrays are equal, no matter the class. */
	return (uintptr_t)self == (uintptr_t)otherArray || otherArray.count == 0;
}

- (NSEnumerator *)objectEnumerator
{
	return _NSZeroArrayEnumeratorInstance;
}

- (NSEnumerator *)reverseObjectEnumerator
{
	return _NSZeroArrayEnumeratorInstance;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	return 0;
}

@end

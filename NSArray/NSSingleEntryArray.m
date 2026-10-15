
#import <FoundationPrivate/NSArray/NSArray.h>

@implementation NSSingleEntryArray {
	id<NSObject> _anObject;
}

- (id)mutableCopy
{
	NSArrayBuffer *const buffer = NSArrayBufferCreate(1);
	buffer->count = 1;
	buffer->objects[0] = objc_retain(_anObject);
	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (instancetype)_initWithObject:(id)anObject OBJC_DIRECT
{
	_anObject = anObject;

	return self;
}

- (NSUInteger)count
{
	return 1;
}

- (nullable id)firstObject
{
	return _anObject;
}

- (nullable id)lastObject
{
	return _anObject;
}

- (NSArray *)arrayByAddingObject:(id)anObject
{
	_NSRequireNonnil(anObject);

	NSArrayBuffer *const buffer = NSArrayBufferCreate(2);
	buffer->count = 2;
	buffer->objects[0] = objc_retain(_anObject);
	buffer->objects[1] = objc_retain(anObject);

	return [[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (NSArray *)arrayByAddingObjectsFromArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	return _NSArrayByAddingObjectsFromArray(((NSArrayRepresentation) {
		self, _NSSingleEntryArrayClass, &_anObject, 1, true
	}), otherArray);
}

- (NSArray *)subarrayWithRange:(NSRange)range
{
	if (range.location == 0 && range.length == 1)
		return self;

	_NSRangeWithinUpperBound(range, 1UL);

	/* Anything else is either {0, 0} or {1, 0}. Valid, but returns an empty array. */
	return (id)_NSZeroArrayInstance;
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	return _NSArrayObjectsAtIndexes(((NSArrayRepresentation) {
		self, _NSSingleEntryArrayClass, &_anObject, 1, true
	}), _NSIndexSetGetRepresentation(indexSet));
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	_NSArrayRequireIndexWithinBounds(index, 1);
	return _anObject;
}

- (void)getObjects:(id _Nonnull __unsafe_unretained [_Nonnull])objects range:(NSRange)range
{
	_NSRequireNonnullptr(objects);

	if (range.location == 0 && range.length == 1)
		objects[0] = _anObject;

	_NSRangeWithinUpperBound(range, (NSUInteger)1);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

- (void)makeObjectsPerformSelector:(SEL)aSelector
{
	[_anObject performSelector:aSelector];
}

- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(nullable id)anObject
{
	[_anObject performSelector:aSelector withObject:anObject];
}

#pragma clang diagnostic pop

- (NSUInteger)indexOfObject:(id)anObject
{
	return [_anObject isEqual:anObject] ? 0 : NSNotFound;
}

- (NSUInteger)indexOfObject:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)1);

	return range.location == 0 && range.length == 1 && [_anObject isEqual:anObject] ? 0 : NSNotFound;
}

- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject
{
	return (uintptr_t)_anObject == (uintptr_t)anObject ? 0 : NSNotFound;
}

- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, (NSUInteger)1);

	return range.location == 0 && range.length == 1 &&
		(uintptr_t)_anObject == (uintptr_t)anObject ? 0 : NSNotFound;
}

- (NSUInteger)indexOfObjectPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, &_anObject, 1, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, 1), 1, 1
	}), NSEnumerationNoOptions, predicate);
}

- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, &_anObject, 1, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, 1), 1, 1
	}), options, predicate);
}

- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, &_anObject, 1, true
	}), _NSIndexSetGetRepresentation(indexSet), options, predicate);
}

- (NSIndexSet *)indexesOfObjectsPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, &_anObject, 1, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, 1), 1, 1
	}), NSEnumerationNoOptions, predicate);
}

- (NSIndexSet *)indexesOfObjectsWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, &_anObject, 1, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, 1), 1, 1
	}), options, predicate);
}

- (NSIndexSet *)indexesOfObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, &_anObject, 1, true
	}), _NSIndexSetGetRepresentation(indexSet), options, predicate);
}

- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, nullptr, &_anObject, 1, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, 1), 1, 1
	}), NSEnumerationNoOptions, block);
}

- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, nullptr, &_anObject, 1, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, 1), 1, 1
	}), options, block);
}

- (void)enumerateObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, nullptr, &_anObject, 1, true
	}), _NSIndexSetGetRepresentation(indexSet), options, block);
}

- (bool)containsObject:(id)anObject
{
	return [_anObject isEqual:anObject];
}

- (NSUInteger)hash
{
	return NSSipHash((NSUInteger[]){ 1, _anObject.hash }, sizeof(NSUInteger) * 2, _NSArrayHashKey);
}

- (bool)isEqualToArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	if ((uintptr_t)self == (uintptr_t)otherArray)
		return true;

	if (otherArray.count != 1)
		return false;

	return [_anObject isEqual:otherArray[0]];
}

- (NSEnumerator *)objectEnumerator
{
	return [NSSingleEntryArrayEnumerator _enumeratorWithObject:_anObject];
}

- (NSEnumerator *)reverseObjectEnumerator
{
	return [NSSingleEntryArrayEnumerator _enumeratorWithObject:_anObject];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	(void)stackBuffer;
	(void)stackBufferCapacity;

	if (state->state == 0) {
		state->state = 1;
		state->mutationsPtr = (unsigned long *)(uintptr_t)self;
		state->itemsPtr = (id __unsafe_unretained *)(void *)&_anObject;
		return 1;
	} else
		return 0;
}

@end

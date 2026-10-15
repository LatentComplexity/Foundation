
#import <FoundationPrivate/NSArray/NSArray.h>

@implementation NSInlineArray {
	NSArrayBuffer *_buffer;
}

- (id)mutableCopy
{
	return (id)[[NSMutableInlineArray alloc] _initWithBuffer:_buffer];
}

- (instancetype)_initWithBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT
{
	_buffer = NSArrayBufferRetain(buffer);

	return self;
}

- (instancetype)_initAdoptingBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT
{
	_buffer = buffer;

	return self;
}

- (NSUInteger)count
{
	return _buffer->count;
}

- (nullable id)firstObject
{
	return _buffer->objects[0];
}

- (nullable id)lastObject
{
	return _buffer->objects[_buffer->count - 1];
}

- (NSArray *)arrayByAddingObject:(id)anObject
{
	_NSRequireNonnil(anObject);

	NSUInteger const count = _buffer->count;
	NSArrayBuffer *const buffer = NSArrayBufferCreate(count + 1);
	buffer->count = count + 1;

	for (NSUInteger i = 0; i < count; ++i)
		buffer->objects[i] = objc_retain(_buffer->objects[i]);

	buffer->objects[count] = objc_retain(anObject);

	return [[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (NSArray *)arrayByAddingObjectsFromArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	return _NSArrayByAddingObjectsFromArray(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), otherArray);
}

- (NSArray *)subarrayWithRange:(NSRange)range
{
	if (range.location == 0 && range.length == _buffer->count)
		return self;

	_NSRangeWithinUpperBound(range, _buffer->count);

	if (range.length == 0)
		return _NSZeroArrayInstance;

	if (range.length == 1)
		return [[NSSingleEntryArray alloc] _initWithObject:_buffer->objects[range.location]];

	return [[NSSubrangeArray alloc] _initWithBuffer:_buffer base:range.location count:range.length];
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	return _NSArrayObjectsAtIndexes(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), _NSIndexSetGetRepresentation(indexSet));
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	_NSArrayRequireIndexWithinBounds(index, _buffer->count);
	return _buffer->objects[index];
}

- (void)getObjects:(id _Nonnull __unsafe_unretained [_Nonnull])objects range:(NSRange)range
{
	_NSRequireNonnullptr(objects);
	_NSRangeWithinUpperBound(range, _buffer->count);

	/* memcpy() with a size of zero is well-defined since C23, right? */
	memcpy(objects, _buffer->objects + range.location, range.length * sizeof(id));
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

- (void)makeObjectsPerformSelector:(SEL)aSelector
{
	for (NSUInteger i = 0; i < _buffer->count; ++i)
		[_buffer->objects[i] performSelector:aSelector];
}

- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(nullable id)anObject
{
	for (NSUInteger i = 0; i < _buffer->count; ++i)
		[_buffer->objects[i] performSelector:aSelector withObject:anObject];
}

#pragma clang diagnostic pop

- (NSUInteger)indexOfObject:(id)anObject
{
	if (anObject == nil)
		return NSNotFound;

	for (NSUInteger i = 0; i < _buffer->count; ++i)
		if ([_buffer->objects[i] isEqual:anObject])
			return i;

	return NSNotFound;
}

- (NSUInteger)indexOfObject:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, _buffer->count);

	if (anObject == nil)
		return NSNotFound;

	for (NSUInteger i = range.location; i < NSRangeMax(range); ++i)
		if ([_buffer->objects[i] isEqual:anObject])
			return i;

	return NSNotFound;
}

- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject
{
	if (anObject == nil)
		return NSNotFound;

	for (NSUInteger i = 0; i < _buffer->count; ++i)
		if ((uintptr_t)_buffer->objects[i] == (uintptr_t)anObject)
			return i;

	return NSNotFound;
}

- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, _buffer->count);

	if (anObject == nil)
		return NSNotFound;

	for (NSUInteger i = range.location; i < NSRangeMax(range); ++i)
		if ((uintptr_t)_buffer->objects[i] == (uintptr_t)anObject)
			return i;

	return NSNotFound;
}

- (NSUInteger)indexOfObjectPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _buffer->count), 1, _buffer->count
	}), NSEnumerationNoOptions, predicate);
}

- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _buffer->count), 1, _buffer->count
	}), options, predicate);
}

- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), _NSIndexSetGetRepresentation(indexSet), options, predicate);
}

- (NSIndexSet *)indexesOfObjectsPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _buffer->count), 1, _buffer->count
	}), NSEnumerationNoOptions, predicate);
}

- (NSIndexSet *)indexesOfObjectsWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _buffer->count), 1, _buffer->count
	}), options, predicate);
}

- (NSIndexSet *)indexesOfObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), _NSIndexSetGetRepresentation(indexSet), options, predicate);
}

- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _buffer->count), 1, _buffer->count
	}), NSEnumerationNoOptions, block);
}

- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _buffer->count), 1, _buffer->count
	}), options, block);
}

- (void)enumerateObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, _NSInlineArrayClass, _buffer->objects, _buffer->count, true
	}), _NSIndexSetGetRepresentation(indexSet), options, block);
}

- (bool)containsObject:(id)anObject
{
	if (anObject == nil)
		return false;

	for (NSUInteger i = 0; i < _buffer->count; ++i)
		if ([_buffer->objects[i] isEqual:anObject])
			return true;

	return false;
}

- (NSUInteger)hash
{
	NSUInteger h = OSAtomicLoad(&_buffer->hash, OSAtomicMemoryOrderRelaxed);

	if (h == 0) {
		NSSipHashContext c;

		NSSipHashContextInit(&c, _NSArrayHashKey);
		NSSipHashWithContext(&c, (NSUInteger[]){ _buffer->count }, sizeof(NSUInteger));

		for (NSUInteger i = 0; i < _buffer->count; ++i)
			NSSipHashWithContext(&c, (NSUInteger[]){ _buffer->objects[i].hash }, sizeof(NSUInteger));

		NSSipHashWithContextFinalize(&c, &h);
		OSAtomicStore(&_buffer->hash, h, OSAtomicMemoryOrderRelaxed);
	}

	return h;
}

- (bool)isEqualToArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	if ((uintptr_t)self == (uintptr_t)otherArray)
		return true;

	Class const c = object_getClass(otherArray);
	id __unsafe_unretained const *otherObjects;
	NSUInteger otherCount;

	if (c == _NSZeroArrayClass || c == _NSSingleEntryArrayClass)
		return false;
	else if (c == _NSInlineArrayClass || c == _NSMutableInlineArrayClass) {
		NSInlineArrayLayout const *const layout = (__bridge NSInlineArrayLayout *)otherArray;
		otherObjects = layout->buffer->objects;
		otherCount = layout->buffer->count;
	} else if (c == _NSSubrangeArrayClass) {
		NSSubrangeArrayLayout const *const layout = (__bridge NSSubrangeArrayLayout *)otherArray;
		otherObjects = layout->buffer->objects + layout->base;
		otherCount = layout->count;
	} else {
		otherObjects = nullptr;
		otherCount = otherArray.count;
	}

	if (_buffer->count != otherCount)
		return false;

	if (otherObjects != nullptr) {
		for (NSUInteger i = 0; i < _buffer->count; ++i)
			if ([_buffer->objects[i] isEqual:otherObjects[i]] == false)
				return false;
	} else {
		for (NSUInteger i = 0; i < _buffer->count; ++i)
			if ([_buffer->objects[i] isEqual:otherArray[i]] == false)
				return false;
	}

	return true;
}

- (NSEnumerator *)objectEnumerator
{
	return [NSInlineArrayEnumerator _enumeratorWithBuffer:_buffer];
}

- (NSEnumerator *)reverseObjectEnumerator
{
	return [NSInlineArrayReverseEnumerator _enumeratorWithBuffer:_buffer];
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
		state->itemsPtr = (id __unsafe_unretained *)_buffer->objects;
		return _buffer->count;
	} else
		return 0;
}

- (void)dealloc
{
	NSArrayBufferRelease(_buffer);
}

@end

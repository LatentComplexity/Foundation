
#import <FoundationPrivate/NSArray/NSArray.h>

@implementation NSSubrangeArray {
	NSArrayBuffer *_buffer;
	NSUInteger _base;
	NSUInteger _count;
	NSUInteger _Atomic _hash;
}

- (id)mutableCopy
{
	NSArrayBuffer *const buffer = NSArrayBufferCreate(_count);
	buffer->count = _count;

	id __unsafe_unretained *objects = _buffer->objects + _base;
	for (NSUInteger i = 0; i < _count; ++i)
		buffer->objects[i] = objc_retain(objects[i]);

	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (instancetype)_initWithBuffer:(NSArrayBuffer *)buffer base:(NSUInteger)base
		count:(NSUInteger)count OBJC_DIRECT
{
	_buffer = NSArrayBufferRetain(buffer);
	_base = base;
	_count = count;

	return self;
}

- (NSUInteger)count
{
	return _count;
}

- (nullable id)firstObject
{
	return _buffer->objects[_base];
}

- (nullable id)lastObject
{
	return _buffer->objects[_base + _count - 1];
}

- (NSArray *)arrayByAddingObject:(id)anObject
{
	_NSRequireNonnil(anObject);

	NSUInteger const count = _count;
	NSArrayBuffer *const buffer = NSArrayBufferCreate(count + 1);
	buffer->count = count + 1;

	id __unsafe_unretained const *const objects = _buffer->objects + _base;
	for (NSUInteger i = 0; i < count; ++i)
		buffer->objects[i] = objc_retain(objects[i]);

	buffer->objects[count] = objc_retain(anObject);

	return [[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (NSArray *)arrayByAddingObjectsFromArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	return _NSArrayByAddingObjectsFromArray(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), otherArray);
}

- (NSArray *)subarrayWithRange:(NSRange)range
{
	if (range.location == 0 && range.length == _count)
		return self;

	_NSRangeWithinUpperBound(range, _count);

	if (range.length == 0)
		return _NSZeroArrayInstance;

	if (range.length == 1)
		return [[NSSingleEntryArray alloc] _initWithObject:_buffer->objects[_base + range.location]];

	/* Flatten the window onto the original buffer. */
	return [[NSSubrangeArray alloc] _initWithBuffer:_buffer base:_base + range.location count:range.length];
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	return _NSArrayObjectsAtIndexes(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), _NSIndexSetGetRepresentation(indexSet));
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	_NSArrayRequireIndexWithinBounds(index, _count);
	return _buffer->objects[_base + index];
}

- (void)getObjects:(id _Nonnull __unsafe_unretained [_Nonnull])objects range:(NSRange)range
{
	_NSRequireNonnullptr(objects);
	_NSRangeWithinUpperBound(range, _count);

	/* memcpy() with a size of zero is well-defined since C23, right? */
	memcpy(objects, _buffer->objects + _base + range.location, range.length * sizeof(id));
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

- (void)makeObjectsPerformSelector:(SEL)aSelector
{
	id<NSObject> __unsafe_unretained const *const objects = _buffer->objects + _base;
	for (NSUInteger i = 0; i < _count; ++i)
		[objects[i] performSelector:aSelector];
}

- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(nullable id)anObject
{
	id<NSObject> __unsafe_unretained const *const objects = _buffer->objects + _base;
	for (NSUInteger i = 0; i < _count; ++i)
		[objects[i] performSelector:aSelector withObject:anObject];
}

#pragma clang diagnostic pop

- (NSUInteger)indexOfObject:(id)anObject
{
	id<NSObject> __unsafe_unretained const *const objects = _buffer->objects + _base;
	for (NSUInteger i = 0; i < _count; ++i)
		if ([objects[i] isEqual:anObject])
			return i;

	return NSNotFound;
}

- (NSUInteger)indexOfObject:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, _count);

	id<NSObject> __unsafe_unretained const *const objects = _buffer->objects + _base;
	for (NSUInteger i = range.location; i < NSRangeMax(range); ++i)
		if ([objects[i] isEqual:anObject])
			return i;

	return NSNotFound;
}

- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject
{
	id __unsafe_unretained const *const objects = _buffer->objects + _base;
	for (NSUInteger i = 0; i < _count; ++i)
		if ((uintptr_t)objects[i] == (uintptr_t)anObject)
			return i;

	return NSNotFound;
}

- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, _count);

	id __unsafe_unretained const *const objects = _buffer->objects + _base;
	for (NSUInteger i = range.location; i < NSRangeMax(range); ++i)
		if ((uintptr_t)objects[i] == (uintptr_t)anObject)
			return i;

	return NSNotFound;
}

- (NSUInteger)indexOfObjectPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _count), 1, _count
	}), NSEnumerationNoOptions, predicate);
}

- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _count), 1, _count
	}), options, predicate);
}

- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), _NSIndexSetGetRepresentation(indexSet), options, predicate);
}

- (NSIndexSet *)indexesOfObjectsPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _count), 1, _count
	}), NSEnumerationNoOptions, predicate);
}

- (NSIndexSet *)indexesOfObjectsWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _count), 1, _count
	}), NSEnumerationNoOptions, predicate);
}

- (NSIndexSet *)indexesOfObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), _NSIndexSetGetRepresentation(indexSet), NSEnumerationNoOptions, predicate);
}

- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _count), 1, _count
	}), NSEnumerationNoOptions, block);
}

- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, _count), 1, _count
	}), options, block);
}

- (void)enumerateObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, _NSSubrangeArrayClass, _buffer->objects + _base, _count, true
	}), _NSIndexSetGetRepresentation(indexSet), options, block);
}

- (bool)containsObject:(id)anObject
{
	if (anObject == nil)
		return false;

	id<NSObject> __unsafe_unretained const *const objects = _buffer->objects + _base;
	for (NSUInteger i = 0; i < _count; ++i)
		if ([objects[i] isEqual:anObject])
			return true;

	return false;
}

- (NSUInteger)hash
{
	NSUInteger h = OSAtomicLoad(&_hash, OSAtomicMemoryOrderRelaxed);

	if (h == 0) {
		NSSipHashContext c;

		NSSipHashContextInit(&c, _NSArrayHashKey);
		NSSipHashWithContext(&c, (NSUInteger[]){ _count }, sizeof(NSUInteger));

		id<NSObject> __unsafe_unretained const *const objects = _buffer->objects + _base;
		for (NSUInteger i = 0; i < _count; ++i)
			NSSipHashWithContext(&c, (NSUInteger[]){ objects[i].hash }, sizeof(NSUInteger));

		NSSipHashWithContextFinalize(&c, &h);
		OSAtomicStore(&_hash, h, OSAtomicMemoryOrderRelaxed);
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

	if (_count != otherCount)
		return false;

	id<NSObject> __unsafe_unretained const *const objects = _buffer->objects + _base;

	if (otherObjects != nullptr) {
		for (NSUInteger i = 0; i < _count; ++i)
			if ([objects[i] isEqual:otherObjects[i]] == false)
				return false;
	} else {
		for (NSUInteger i = 0; i < _count; ++i)
			if ([objects[i] isEqual:otherArray[i]] == false)
				return false;
	}

	return true;
}

- (NSEnumerator *)objectEnumerator
{
	return [NSSubrangeArrayEnumerator _enumeratorWithBuffer:_buffer base:_base count:_count];
}

- (NSEnumerator *)reverseObjectEnumerator
{
	return [NSSubrangeArrayReverseEnumerator _enumeratorWithBuffer:_buffer base:_base count:_count];
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
		state->itemsPtr = (id __unsafe_unretained *)(void *)(_buffer->objects + _base);
		return _count;
	} else
		return 0;
}

- (void)dealloc
{
	NSArrayBufferRelease(_buffer);
}

@end

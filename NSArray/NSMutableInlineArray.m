
#import <FoundationPrivate/NSArray/NSArray.h>

@interface NSMutableInlineArray ()

- (void)_detachEnsuringCapacity:(NSUInteger)minCapacity OBJC_DIRECT;
- (void)_detachOpeningGapAtLocation:(NSUInteger)location removing:(NSUInteger)removeLength
	inserting:(NSUInteger)insertLength OBJC_DIRECT;
- (void)_detachDiscardingContentsEnsuringCapacity:(NSUInteger)minCapacity OBJC_DIRECT;
- (void)_replaceObjectsInRange:(NSRange)range withObjects:(id __unsafe_unretained _Nonnull const *_Nullable)objects
	base:(NSUInteger)base count:(NSUInteger)count OBJC_DIRECT;

@end

static NSArrayBuffer *
NSMutableInlineArrayCreateForeignSnapshot(NSMethodContext const ctx, char const *const arrayName,
					NSArray *array, NSUInteger const base, NSUInteger const count)
{
	NSArrayBuffer *const buffer = NSArrayBufferCreate(count);

	for (NSUInteger i = 0; i < count; ++i) {
		NSUInteger const sourceIndex = base + i;
		id __unsafe_unretained obj = array[sourceIndex];

		if (obj == nil) {
			/* Exceptions are fatal; free the exclusive allocations and accept retained-object leaks. */
			free(buffer->objects);
			free(buffer);
			_NSRaiseException(ctx, NSInvalidArgumentException, @"'%s' returned nil at index %lu.",
					arrayName, sourceIndex);
		}

		buffer->objects[i] = objc_retain(obj);
	}

	buffer->count = count;
	return buffer;
}

static void
NSMutableInlineArrayDisposeExclusiveSnapshot(NSArrayBuffer *const buffer)
{
	for (NSUInteger i = 0; i < buffer->count; ++i)
		objc_release(buffer->objects[i]);

	free(buffer->objects);
	free(buffer);
}

@implementation NSMutableInlineArray {
	NSArrayBuffer *_buffer;
	unsigned long _mutations;
}

- (id)copy
{
	if (_buffer->count == 0)
		return _NSZeroArrayInstance;
	if (_buffer->count == 1)
		return [[NSSingleEntryArray alloc] _initWithObject:_buffer->objects[0]];

	return [[NSInlineArray alloc] _initWithBuffer:_buffer];
}

- (id)mutableCopy
{
	return [[NSMutableInlineArray alloc] _initWithBuffer:_buffer];
}

- (instancetype)_initWithBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT
{
	_buffer = NSArrayBufferRetain(buffer);
	_mutations = 0;

	return self;
}

- (instancetype)_initAdoptingBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT
{
	_buffer = buffer;
	_mutations = 0;

	return self;
}

/* Preserve the logical count, forking shared storage or growing unique storage in place. */
- (void)_detachEnsuringCapacity:(NSUInteger)minCapacity OBJC_DIRECT
{
	if (NSArrayBufferIsUniquelyReferenced(_buffer) == false) {
		NSArrayBuffer *const fresh = NSArrayBufferCreate(MAX(minCapacity, _buffer->count));

		for (NSUInteger i = 0; i < _buffer->count; ++i)
			fresh->objects[i] = objc_retain(_buffer->objects[i]);

		fresh->count = _buffer->count;
		NSArrayBufferRelease(_buffer);
		_buffer = fresh;
	} else {
		NSArrayBufferReserve(_buffer, minCapacity);
		OSAtomicStore(&_buffer->hash, (NSUInteger)0, OSAtomicMemoryOrderRelaxed);
	}
}

/*
 * Move the surviving head and tail directly to their final positions, leaving the replacement gap uninitialized.
 * The caller has already validated the removed range and the resulting count.
 */
- (void)_detachOpeningGapAtLocation:(NSUInteger)location removing:(NSUInteger)removeLength
	inserting:(NSUInteger)insertLength OBJC_DIRECT
{
	NSUInteger const oldCount = _buffer->count;
	NSUInteger const newCount = oldCount - removeLength + insertLength;
	NSUInteger const tailLocation = location + removeLength;
	NSUInteger const tailCount = oldCount - tailLocation;

	if (NSArrayBufferIsUniquelyReferenced(_buffer) == false) {
		NSArrayBuffer *const fresh = NSArrayBufferCreate(newCount);

		for (NSUInteger i = 0; i < location; ++i)
			fresh->objects[i] = objc_retain(_buffer->objects[i]);

		for (NSUInteger i = 0; i < tailCount; ++i)
			fresh->objects[location + insertLength + i] =
				objc_retain(_buffer->objects[tailLocation + i]);

		fresh->count = newCount;
		NSArrayBufferRelease(_buffer);
		_buffer = fresh;
	} else {
		NSArrayBufferReserve(_buffer, newCount);

		for (NSUInteger i = 0; i < removeLength; ++i)
			objc_release(_buffer->objects[location + i]);

		if (tailCount > 0 && insertLength != removeLength)
			memmove(_buffer->objects + location + insertLength,
				_buffer->objects + tailLocation, tailCount * sizeof(id));

		_buffer->count = newCount;
		OSAtomicStore(&_buffer->hash, (NSUInteger)0, OSAtomicMemoryOrderRelaxed);
	}
}

/* Drop all elements without copying a shared buffer whose contents will be overwritten or removed. */
- (void)_detachDiscardingContentsEnsuringCapacity:(NSUInteger)minCapacity OBJC_DIRECT
{
	if (NSArrayBufferIsUniquelyReferenced(_buffer)) {
		for (NSUInteger i = 0; i < _buffer->count; ++i)
			objc_release(_buffer->objects[i]);

		_buffer->count = 0;
		NSArrayBufferReserve(_buffer, minCapacity);
		OSAtomicStore(&_buffer->hash, (NSUInteger)0, OSAtomicMemoryOrderRelaxed);
	} else {
		NSArrayBufferRelease(_buffer);
		_buffer = NSArrayBufferCreate(minCapacity);
	}
}

- (void)_replaceObjectsInRange:(NSRange)range withObjects:(id __unsafe_unretained _Nonnull const *_Nullable)objects
	base:(NSUInteger)base count:(NSUInteger)count OBJC_DIRECT
{
	if (range.length == count) {
		bool identical = true;

		for (NSUInteger i = 0; i < count; ++i) {
			if ((uintptr_t)_buffer->objects[range.location + i] != (uintptr_t)objects[base + i]) {
				identical = false;
				break;
			}
		}

		if (identical)
			return;
	}

	[self _detachOpeningGapAtLocation:range.location removing:range.length inserting:count];

	for (NSUInteger i = 0; i < count; ++i)
		_buffer->objects[range.location + i] = objc_retain(objects[base + i]);

	++_mutations;
}

- (NSUInteger)count
{
	return _buffer->count;
}

- (nullable id)firstObject
{
	return _buffer->count != 0 ? _buffer->objects[0] : nil;
}

- (nullable id)lastObject
{
	return _buffer->count != 0 ? _buffer->objects[_buffer->count - 1] : nil;
}

- (NSArray *)arrayByAddingObject:(id)anObject
{
	_NSRequireNonnil(anObject);

	NSUInteger const count = _buffer->count;
	if (count == 0)
		return [[NSSingleEntryArray alloc] _initWithObject:anObject];
	if (count >= NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

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
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
	}), otherArray);
}

- (NSArray *)subarrayWithRange:(NSRange)range
{
	if (range.location == 0 && range.length == _buffer->count)
		return [self copy];

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
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
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
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
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
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
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
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
	}), _NSIndexSetGetRepresentation(indexSet), options, predicate);
}

- (NSIndexSet *)indexesOfObjectsPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
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
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
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
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
	}), _NSIndexSetGetRepresentation(indexSet), options, predicate);
}

- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
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
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
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
		self, _NSMutableInlineArrayClass, _buffer->objects, _buffer->count, true
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
	if (_buffer->count == 0)
		return _NSZeroArrayHash;

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

	if (c == _NSZeroArrayClass) {
		otherObjects = nullptr;
		otherCount = 0;
	} else if (c == _NSSingleEntryArrayClass) {
		otherObjects = &((__bridge NSSingleEntryArrayLayout *)otherArray)->anObject;
		otherCount = 1;
	} else if (c == _NSInlineArrayClass || c == _NSMutableInlineArrayClass) {
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
	return [NSMutableInlineArrayEnumerator _enumeratorWithArray:self];
}

- (NSEnumerator *)reverseObjectEnumerator
{
	return [NSMutableInlineArrayReverseEnumerator _enumeratorWithArray:self];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	(void)stackBuffer;
	(void)stackBufferCapacity;

	if (state->state == 0) {
		state->state = 1;
		state->mutationsPtr = &_mutations;
		state->itemsPtr = (id __unsafe_unretained *)_buffer->objects;
		return _buffer->count;
	} else
		return 0;
}

#pragma mark - Mutators

- (void)addObject:(id)anObject
{
	_NSRequireNonnil(anObject);

	NSUInteger const oldCount = _buffer->count;
	if (oldCount >= NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

	[self _detachEnsuringCapacity:oldCount + 1];
	_buffer->objects[oldCount] = objc_retain(anObject);
	_buffer->count = oldCount + 1;
	++_mutations;
}

- (void)addObjectsFromArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	NSArrayRepresentation source = _NSArrayGetRepresentation(otherArray);

	if (source.count == 0)
		return;

	NSUInteger const oldCount = _buffer->count;
	NSUInteger newCount;
	if (__builtin_add_overflow(oldCount, source.count, &newCount) || newCount > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

	[self _detachEnsuringCapacity:newCount];

	/* Appending self reads from the post-detachment buffer, so reserve cannot stale a captured pointer. */
	if ((uintptr_t)otherArray == (uintptr_t)self) {
		for (NSUInteger i = 0; i < oldCount; ++i)
			_buffer->objects[oldCount + i] = objc_retain(_buffer->objects[i]);

		_buffer->count = newCount;
		++_mutations;
		return;
	}

	/* Yank the objects out of the other array. */
	if (source.objects != nullptr) {
		for (NSUInteger i = 0; i < source.count; ++i)
			_buffer->objects[oldCount + i] = objc_retain(source.objects[i]);
	} else {
		for (NSUInteger i = 0; i < source.count; ++i) {
			id __unsafe_unretained obj = otherArray[i];
			_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, obj, i);
			_buffer->objects[oldCount + i] = objc_retain(obj);
		}
	}

	_buffer->count = newCount;
	++_mutations;
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)index
{
	_NSRequireNonnil(anObject);

	NSUInteger const oldCount = _buffer->count;
	if (index > oldCount)
		_NSRaiseException(MethodContext, NSRangeException,
			@"'index' with value %lu extends beyond insertion bound of %lu.", index, oldCount);

	if (oldCount >= NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

	[self _detachOpeningGapAtLocation:index removing:0 inserting:1];
	_buffer->objects[index] = objc_retain(anObject);
	++_mutations;
}

/* TODO: bleh. */
- (void)insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexes
{
	_NSRequireNonnil(objects);
	_NSRequireNonnil(indexes);

	NSArrayRepresentation source = _NSArrayGetRepresentation(objects);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(objects, source.count);

	NSIndexSetRepresentation const indexRep = _NSIndexSetGetRepresentation(indexes);
	if (source.count != indexRep.count)
		_NSRaiseException(MethodContext, NSInvalidArgumentException,
			@"'objects' count of %lu differs from 'indexes' count of %lu.",
			source.count, indexRep.count);

	if (source.count == 0)
		return;

	NSUInteger const oldCount = _buffer->count;
	NSUInteger newCount;
	if (__builtin_add_overflow(oldCount, source.count, &newCount) || newCount > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

	NSRange const oneRange = indexRep.rangeCount == 1 ? indexRep.r.range : NSRangeZero;
	NSRange const *const ranges = indexRep.rangeCount == 1 ? &oneRange : indexRep.r.ranges;
	if (NSRangeMax(ranges[indexRep.rangeCount - 1]) > newCount)
		_NSRaiseException(MethodContext, NSRangeException,
			@"'indexes' extends beyond insertion bound of %lu.", newCount);

	/* Stabilize foreign input and self before reserving or moving the receiver's storage. */
	NSArrayBuffer *snapshot = nullptr;
	NSArrayBuffer *sourceHold = nullptr;
	if (source.objects == nullptr) {
		snapshot = NSMutableInlineArrayCreateForeignSnapshot(MethodContext, "objects", objects, 0, source.count);
		source.objects = snapshot->objects;
	} else if ((uintptr_t)objects == (uintptr_t)self) {
		sourceHold = NSArrayBufferRetain(_buffer);
		source.objects = sourceHold->objects;
	}

	[self _detachEnsuringCapacity:newCount];

	/* Merge backwards so every old object is moved before its slot can be overwritten. */
	NSUInteger finalEnd = newCount;
	NSUInteger oldEnd = oldCount;
	NSUInteger sourceEnd = source.count;

	for (NSUInteger i = indexRep.rangeCount; i > 0; --i) {
		NSRange const range = ranges[i - 1];
		NSUInteger const rangeEnd = NSRangeMax(range);
		NSUInteger const tailCount = finalEnd - rangeEnd;

		if (tailCount > 0) {
			finalEnd -= tailCount;
			oldEnd -= tailCount;
			memmove(_buffer->objects + finalEnd, _buffer->objects + oldEnd,
				tailCount * sizeof(id));
		}

		finalEnd -= range.length;
		sourceEnd -= range.length;
		for (NSUInteger j = 0; j < range.length; ++j)
			_buffer->objects[finalEnd + j] = objc_retain(source.objects[sourceEnd + j]);
	}

	_buffer->count = newCount;
	++_mutations;

	if (snapshot != nullptr)
		NSMutableInlineArrayDisposeExclusiveSnapshot(snapshot);
	if (sourceHold != nullptr)
		NSArrayBufferRelease(sourceHold);
}

- (void)exchangeObjectAtIndex:(NSUInteger)firstIndex withObjectAtIndex:(NSUInteger)secondIndex
{
	_NSArrayRequireIndexWithinBounds(firstIndex, _buffer->count);
	_NSArrayRequireIndexWithinBounds(secondIndex, _buffer->count);

	if (firstIndex == secondIndex)
		return;

	[self _detachEnsuringCapacity:_buffer->count];
	id __unsafe_unretained const temp = _buffer->objects[firstIndex];
	_buffer->objects[firstIndex] = _buffer->objects[secondIndex];
	_buffer->objects[secondIndex] = temp;
	++_mutations;
}

- (void)removeObject:(id)anObject
{
	if (anObject == nil)
		return;

	/* Find the first match in the array. */
	NSUInteger firstMatch = NSNotFound;
	for (NSUInteger i = 0; i < _buffer->count; ++i) {
		if ([_buffer->objects[i] isEqual:anObject]) {
			firstMatch = i;
			break;
		}
	}

	if (firstMatch == NSNotFound)
		return;

	/* Detach and start looping from the first match, releasing equal objects and writing over in place. */
	id __unsafe_unretained const needle = objc_retain(anObject);
	NSUInteger const oldCount = _buffer->count;

	[self _detachEnsuringCapacity:oldCount];

	NSUInteger writeIndex = firstMatch;
	for (NSUInteger readIndex = firstMatch; readIndex < oldCount; ++readIndex) {
		id<NSObject> __unsafe_unretained const object = _buffer->objects[readIndex];

		if ([object isEqual:needle])
			objc_release(object);
		else
			_buffer->objects[writeIndex++] = object;
	}

	objc_release(needle);
	_buffer->count = writeIndex;
	++_mutations;
}

- (void)removeObject:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, _buffer->count);

	if (anObject == nil || range.length == 0)
		return;

	NSUInteger const rangeEnd = NSRangeMax(range);
	NSUInteger firstMatch = NSNotFound;
	for (NSUInteger i = range.location; i < rangeEnd; ++i) {
		if ([_buffer->objects[i] isEqual:anObject]) {
			firstMatch = i;
			break;
		}
	}

	if (firstMatch == NSNotFound)
		return;

	id __unsafe_unretained const needle = objc_retain(anObject);
	NSUInteger const oldCount = _buffer->count;

	[self _detachEnsuringCapacity:oldCount];

	NSUInteger writeIndex = firstMatch;
	for (NSUInteger readIndex = firstMatch; readIndex < rangeEnd; ++readIndex) {
		id<NSObject> __unsafe_unretained const object = _buffer->objects[readIndex];

		if ([object isEqual:needle])
			objc_release(object);
		else
			_buffer->objects[writeIndex++] = object;
	}

	/* Yank the remaining objects backwards in their new place after all instances of anObject are removed. */
	NSUInteger const tailCount = oldCount - rangeEnd;
	if (tailCount > 0)
		memmove(_buffer->objects + writeIndex, _buffer->objects + rangeEnd, tailCount * sizeof(id));

	objc_release(needle);
	_buffer->count = writeIndex + tailCount;
	++_mutations;
}

- (void)removeObjectIdenticalTo:(id)anObject
{
	if (anObject == nil)
		return;

	NSUInteger firstMatch = NSNotFound;
	for (NSUInteger i = 0; i < _buffer->count; ++i) {
		if ((uintptr_t)_buffer->objects[i] == (uintptr_t)anObject) {
			firstMatch = i;
			break;
		}
	}

	if (firstMatch == NSNotFound)
		return;

	uintptr_t const needle = (uintptr_t)anObject;
	NSUInteger const oldCount = _buffer->count;
	[self _detachEnsuringCapacity:oldCount];

	NSUInteger writeIndex = firstMatch;
	for (NSUInteger readIndex = firstMatch; readIndex < oldCount; ++readIndex) {
		id __unsafe_unretained const object = _buffer->objects[readIndex];

		if ((uintptr_t)object == needle)
			objc_release(object);
		else
			_buffer->objects[writeIndex++] = object;
	}

	_buffer->count = writeIndex;
	++_mutations;
}

/* TODO: parametrize. */
- (void)removeObjectIdenticalTo:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, _buffer->count);

	if (anObject == nil || range.length == 0)
		return;

	NSUInteger const rangeEnd = NSRangeMax(range);
	NSUInteger firstMatch = NSNotFound;
	for (NSUInteger i = range.location; i < rangeEnd; ++i) {
		if ((uintptr_t)_buffer->objects[i] == (uintptr_t)anObject) {
			firstMatch = i;
			break;
		}
	}

	if (firstMatch == NSNotFound)
		return;

	uintptr_t const needle = (uintptr_t)anObject;
	NSUInteger const oldCount = _buffer->count;
	[self _detachEnsuringCapacity:oldCount];

	NSUInteger writeIndex = firstMatch;
	for (NSUInteger readIndex = firstMatch; readIndex < rangeEnd; ++readIndex) {
		id __unsafe_unretained const object = _buffer->objects[readIndex];

		if ((uintptr_t)object == needle)
			objc_release(object);
		else
			_buffer->objects[writeIndex++] = object;
	}

	NSUInteger const tailCount = oldCount - rangeEnd;
	if (tailCount > 0)
		memmove(_buffer->objects + writeIndex, _buffer->objects + rangeEnd,
			tailCount * sizeof(id));

	_buffer->count = writeIndex + tailCount;
	++_mutations;
}

- (void)removeObjectAtIndex:(NSUInteger)index
{
	_NSArrayRequireIndexWithinBounds(index, _buffer->count);

	[self _detachOpeningGapAtLocation:index removing:1 inserting:0];
	++_mutations;
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes
{
	_NSRequireNonnil(indexes);

	/* Don't remove anything if the index set contains no indexes. */
	NSIndexSetRepresentation const rep = _NSIndexSetGetRepresentation(indexes);
	if (rep.count == 0)
		return;

	/* Make sure the index set is within our array bounds. */
	NSRange const oneRange = rep.rangeCount == 1 ? rep.r.range : NSRangeZero;
	NSRange const *const ranges = rep.rangeCount == 1 ? &oneRange : rep.r.ranges;
	if (NSRangeMax(ranges[rep.rangeCount - 1]) > _buffer->count)
		_NSRaiseException(MethodContext, NSRangeException,
			@"'indexes' extends beyond array count of %lu.", _buffer->count);

	/* If the index set contains a single range, we can merely delete the gap. */
	if (rep.rangeCount == 1) {
		[self _detachOpeningGapAtLocation:oneRange.location removing:oneRange.length inserting:0];
		++_mutations;
		return;
	}

	NSUInteger const oldCount = _buffer->count;

	[self _detachEnsuringCapacity:oldCount];

	/* Mark down the first index where we start removing objects. */
	NSUInteger writeIndex = ranges[0].location;
	for (NSUInteger i = 0; i < rep.rangeCount; ++i) {
		NSRange const range = ranges[i];
		NSUInteger const rangeEnd = NSRangeMax(range);

		/* For all objects in our removal range, release them. */
		for (NSUInteger j = range.location; j < rangeEnd; ++j)
			objc_release(_buffer->objects[j]);

		/*
		 * If there are any objects between the end of this removal range and the start of the next removal
		 * range, move them backwards. This keeps the index set's ranges stable. writeIndex keeps track of
		 * where the next bunch will go.
		 */
		NSUInteger const nextLocation = i + 1 < rep.rangeCount ? ranges[i + 1].location : oldCount;
		NSUInteger const liveCount = nextLocation - rangeEnd;
		if (liveCount > 0) {
			memmove(_buffer->objects + writeIndex, _buffer->objects + rangeEnd, liveCount * sizeof(id));
			writeIndex += liveCount;
		}
	}

	_buffer->count = oldCount - rep.count;
	++_mutations;
}

- (void)removeObjectsInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, _buffer->count);

	if (range.length == 0)
		return;

	[self _detachOpeningGapAtLocation:range.location removing:range.length inserting:0];
	++_mutations;
}

- (void)removeObjectsInArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	if (_buffer->count == 0)
		return;

	if ((uintptr_t)otherArray == (uintptr_t)self) {
		[self _detachDiscardingContentsEnsuringCapacity:0];
		++_mutations;
		return;
	}

	/* Get array representation and validate. */
	NSArrayRepresentation source = _NSArrayGetRepresentation(otherArray);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(otherArray, source.count);

	if (source.count == 0)
		return;

	NSUInteger const oldCount = _buffer->count;

	[self _detachEnsuringCapacity:oldCount];

	NSUInteger writeIndex = 0;
	for (NSUInteger i = 0; i < oldCount; ++i) {
		id<NSObject> __unsafe_unretained const object = _buffer->objects[i];
		bool remove = false;

		/* If something in the other array is equal to our object, release our reference to it. */
		if (source.objects != nullptr) {
			for (NSUInteger j = 0; j < source.count; ++j) {
				if ([object isEqual:source.objects[j]]) {
					remove = true;
					break;
				}
			}
		} else {
			for (NSUInteger j = 0; j < source.count; ++j) {
				id __unsafe_unretained obj = otherArray[j];
				_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, obj, j);
				if ([object isEqual:obj]) {
					remove = true;
					break;
				}
			}
		}

		if (remove)
			objc_release(object);
		else
			_buffer->objects[writeIndex++] = object;
	}

	_buffer->count = writeIndex;
	++_mutations;
}

- (void)removeLastObject
{
	if (_buffer->count == 0)
		_NSRaiseException(MethodContext, NSRangeException,
			@"cannot remove the last object from an empty array.");

	[self _detachOpeningGapAtLocation:_buffer->count - 1 removing:1 inserting:0];
	++_mutations;
}

- (void)removeAllObjects
{
	if (_buffer->count == 0)
		return;

	[self _detachDiscardingContentsEnsuringCapacity:0];
	++_mutations;
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject
{
	_NSRequireNonnil(anObject);
	_NSArrayRequireIndexWithinBounds(index, _buffer->count);

	if ((uintptr_t)_buffer->objects[index] == (uintptr_t)anObject)
		return;

	[self _detachEnsuringCapacity:_buffer->count];

	id __unsafe_unretained const replacement = objc_retain(anObject);
	objc_release(_buffer->objects[index]);
	_buffer->objects[index] = replacement;
	++_mutations;
}

/* TODO: yuck. */
- (void)replaceObjectsAtIndexes:(NSIndexSet *)indexes withObjects:(NSArray *)objects
{
	_NSRequireNonnil(indexes);
	_NSRequireNonnil(objects);

	NSIndexSetRepresentation const indexRep = _NSIndexSetGetRepresentation(indexes);
	NSArrayRepresentation source = _NSArrayGetRepresentation(objects);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(objects, source.count);

	if (source.count != indexRep.count)
		_NSRaiseException(MethodContext, NSInvalidArgumentException,
			@"'objects' count of %lu differs from 'indexes' count of %lu.",
			source.count, indexRep.count);

	if (indexRep.count == 0)
		return;

	NSRange const oneRange = indexRep.rangeCount == 1 ? indexRep.r.range : NSRangeZero;
	NSRange const *const ranges = indexRep.rangeCount == 1 ? &oneRange : indexRep.r.ranges;
	if (NSRangeMax(ranges[indexRep.rangeCount - 1]) > _buffer->count)
		_NSRaiseException(MethodContext, NSRangeException,
			@"'indexes' extends beyond array count of %lu.", _buffer->count);

	/* Equal counts plus in-bounds distinct indexes means self supplies the same complete index sequence. */
	/* TODO: figure out how to compare NSArrayBuffer pointers. */
	if ((uintptr_t)objects == (uintptr_t)self)
		return;

	[self _detachEnsuringCapacity:_buffer->count];

	NSUInteger sourceIndex = 0;
	for (NSUInteger i = 0; i < indexRep.rangeCount; ++i) {
		NSRange const range = ranges[i];

		if (source.objects != nullptr) {
			for (NSUInteger j = range.location; j < NSRangeMax(range); ++j, ++sourceIndex) {
				id __unsafe_unretained const replacement = objc_retain(source.objects[sourceIndex]);
				objc_release(_buffer->objects[j]);
				_buffer->objects[j] = replacement;
			}
		} else {
			for (NSUInteger j = range.location; j < NSRangeMax(range); ++j, ++sourceIndex) {
				id __unsafe_unretained const replacement = objc_retain(objects[sourceIndex]);
				_NSForeignArrayRequireNonnilObjectAtIndex(objects, replacement, j);
				objc_release(_buffer->objects[j]);
				_buffer->objects[j] = replacement;
			}
		}
	}

	++_mutations;
}

/* TODO: bleh. */
- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);
	_NSRangeWithinUpperBound(range, _buffer->count);

	NSArrayRepresentation source = _NSArrayGetRepresentation(otherArray);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(otherArray, source.count);

	NSUInteger newCount;
	if (__builtin_add_overflow(_buffer->count - range.length, source.count, &newCount) ||
	    newCount > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");
	(void)newCount;

	NSArrayBuffer *snapshot = nullptr;
	NSArrayBuffer *sourceHold = nullptr;
	if (source.objects == nullptr && source.count > 0) {
		snapshot = NSMutableInlineArrayCreateForeignSnapshot(MethodContext, "otherArray",
							otherArray, 0, source.count);
		source.objects = snapshot->objects;
	} else if ((uintptr_t)otherArray == (uintptr_t)self) {
		sourceHold = NSArrayBufferRetain(_buffer);
		source.objects = sourceHold->objects;
	}

	[self _replaceObjectsInRange:range withObjects:source.objects base:0 count:source.count];

	if (snapshot != nullptr)
		NSMutableInlineArrayDisposeExclusiveSnapshot(snapshot);
	if (sourceHold != nullptr)
		NSArrayBufferRelease(sourceHold);
}

/* TODO: this is horrible. */
- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray *)otherArray range:(NSRange)otherRange
{
	_NSRequireNonnil(otherArray);
	_NSRangeWithinUpperBound(range, _buffer->count);

	NSArrayRepresentation source = _NSArrayGetRepresentation(otherArray);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(otherArray, source.count);

	_NSRangeWithinUpperBound(otherRange, source.count);

	NSUInteger newCount;
	if (__builtin_add_overflow(_buffer->count - range.length, otherRange.length, &newCount) ||
	    newCount > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

	NSArrayBuffer *snapshot = nullptr;
	NSArrayBuffer *sourceHold = nullptr;
	NSUInteger sourceBase = otherRange.location;

	if (source.objects == nullptr && otherRange.length > 0) {
		snapshot = NSMutableInlineArrayCreateForeignSnapshot(MethodContext, "otherArray",
							otherArray, otherRange.location, otherRange.length);
		source.objects = snapshot->objects;
		sourceBase = 0;
	} else if ((uintptr_t)otherArray == (uintptr_t)self) {
		sourceHold = NSArrayBufferRetain(_buffer);
		source.objects = sourceHold->objects;
	}

	[self _replaceObjectsInRange:range withObjects:source.objects base:sourceBase count:otherRange.length];

	if (snapshot != nullptr)
		NSMutableInlineArrayDisposeExclusiveSnapshot(snapshot);
	if (sourceHold != nullptr)
		NSArrayBufferRelease(sourceHold);
}

- (void)setObject:(id)anObject atIndexedSubscript:(NSUInteger)index
{
	_NSRequireNonnil(anObject);

	NSUInteger const count = _buffer->count;
	if (index > count)
		_NSRaiseException(MethodContext, NSRangeException,
			@"'index' with value %lu extends beyond insertion bound of %lu.", index, count);

	/* If the index is one past the last current index, add it. */
	if (index == count) {
		if (count >= NSArrayBufferMaximumCount)
			_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

		[self _detachEnsuringCapacity:count + 1];
		_buffer->objects[count] = objc_retain(anObject);
		_buffer->count = count + 1;
		++_mutations;
		return;
	}

	/* If the object is exactly the same, don't bother. */
	if ((uintptr_t)_buffer->objects[index] == (uintptr_t)anObject)
		return;

	[self _detachEnsuringCapacity:count];

	id __unsafe_unretained const replacement = objc_retain(anObject);
	objc_release(_buffer->objects[index]);
	_buffer->objects[index] = replacement;
	++_mutations;
}

- (void)setArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	if ((uintptr_t)otherArray == (uintptr_t)self)
		return;

	NSArrayRepresentation source = _NSArrayGetRepresentation(otherArray);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(otherArray, source.count);

	/* Whole buffer-backed arrays can be adopted as a CoW snapshot without copying their elements. */
	if (source.arrayCls == _NSInlineArrayClass || source.arrayCls == _NSMutableInlineArrayClass) {
		NSInlineArrayLayout const *const layout = (__bridge NSInlineArrayLayout *)otherArray;
		NSArrayBuffer *const sourceBuffer = (NSArrayBuffer *)(uintptr_t)layout->buffer;

		if (sourceBuffer == _buffer)
			return;

		NSArrayBufferRetain(sourceBuffer);
		NSArrayBufferRelease(_buffer);
		_buffer = sourceBuffer;
		++_mutations;
		return;
	}

	/* The other array holds nothing; clear our buffer. */
	if (source.count == 0) {
		if (_buffer->count == 0)
			return;

		[self _detachDiscardingContentsEnsuringCapacity:0];
		++_mutations;
		return;
	}

	/* We don't completely own our buffer; detach and copy in. */
	if (NSArrayBufferIsUniquelyReferenced(_buffer) == false) {
		NSArrayBufferRelease(_buffer);
		_buffer = NSArrayBufferCreate(source.count);
		_buffer->count = source.count;

		if (source.objects != nullptr) {
			for (NSUInteger i = 0; i < source.count; ++i)
				_buffer->objects[i] = objc_retain(source.objects[i]);
		} else {
			for (NSUInteger i = 0; i < source.count; ++i) {
				id __unsafe_unretained obj = objc_retain(otherArray[i]);
				_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, obj, i);
				_buffer->objects[i] = obj;
			}
		}

		++_mutations;
		return;
	}

	/* We own our buffer. If we can avoid reallocating, set new objects in place. */
	if (source.count <= _buffer->capacity) {
		NSUInteger const oldCount = _buffer->count;

		/* Release and set the incoming objects within _buffer->count. */
		NSUInteger const withinCount = MIN(source.count, oldCount);
		if (source.objects != nullptr) {
			for (NSUInteger i = 0; i < withinCount; ++i) {
				id __unsafe_unretained obj = objc_retain(source.objects[i]);
				objc_release(_buffer->objects[i]);
				_buffer->objects[i] = obj;
			}
		} else {
			for (NSUInteger i = 0; i < withinCount; ++i) {
				id __unsafe_unretained obj = objc_retain(otherArray[i]);
				_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, obj, i);
				objc_release(_buffer->objects[i]);
				_buffer->objects[i] = obj;
			}
		}

		/* Release the remaining objects in the buffer, if any. */
		for (NSUInteger i = withinCount; i < oldCount; ++i)
			objc_release(_buffer->objects[i]);

		/* If the incoming array is longer, retain and set the objects beyond the old logical end. */
		if (source.count > oldCount) {
			if (source.objects != nullptr) {
				for (NSUInteger i = oldCount; i < source.count; ++i)
					_buffer->objects[i] = objc_retain(source.objects[i]);
			} else {
				for (NSUInteger i = oldCount; i < source.count; ++i) {
					id __unsafe_unretained obj = objc_retain(otherArray[i]);
					_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, obj, i);
					_buffer->objects[i] = obj;
				}
			}
		}

		_buffer->count = source.count;
		OSAtomicStore(&_buffer->hash, (NSUInteger)0, OSAtomicMemoryOrderRelaxed);
		++_mutations;
		return;
	}

	/* We own our buffer, but cannot fit the other array. Release and create a new array, then copy in. */
	for (NSUInteger i = 0; i < _buffer->count; ++i)
		objc_release(_buffer->objects[i]);

	free(_buffer->objects);

	_buffer->objects = (id __unsafe_unretained *)_NSMalloc(source.count * sizeof(id));
	_buffer->count = source.count;
	_buffer->capacity = source.count;
	OSAtomicInit(&_buffer->hash, 0);

	/* Copy in our new objects. */
	if (source.objects != nullptr) {
		for (NSUInteger i = 0; i < _buffer->count; ++i)
			_buffer->objects[i] = objc_retain(source.objects[i]);
	} else {
		for (NSUInteger i = 0; i < _buffer->count; ++i) {
			id __unsafe_unretained obj = objc_retain(otherArray[i]);
			_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, obj, i);
			_buffer->objects[i] = obj;
		}
	}

	++_mutations;
	return;
}

- (void)dealloc
{
	NSArrayBufferRelease(_buffer);
}

@end

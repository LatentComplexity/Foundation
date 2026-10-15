
#import <FoundationPrivate/NSArray/NSArray.h>

@implementation NSMutableArray

static NSMutableArrayTemplate *_NSMutableArrayTemplateInstance = nil;

+ (void)initialize
{
	static NSCallOnceState s = {};

	if (self == [NSArray class] || self == [NSMutableArray class])
		NSCallOnce(&s, ^{
			_NSMutableArrayTemplateInstance = [NSMutableArrayTemplate alloc];
		});
}

+ (instancetype)alloc
{
	if (self == _NSMutableArrayClass)
		return _NSMutableArrayTemplateInstance;

	return class_createInstance(self, 0);
}

- (id)copy
{
	NSUInteger const count = self.count;

	NSArrayBuffer *const buffer = NSArrayBufferCreate(count);
	buffer->count = count;

	NSUInteger i = 0;
	for (id __unsafe_unretained obj in self) {
		_NSForeignReceiverArrayRequireNonnilObjectAtIndex(obj, i);
		buffer->objects[i] = objc_retain(obj);
		++i;
	}

	return (id)[[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (id)mutableCopy
{
	NSUInteger const count = self.count;

	NSArrayBuffer *const buffer = NSArrayBufferCreate(count);
	buffer->count = count;

	NSUInteger i = 0;
	for (id __unsafe_unretained obj in self) {
		_NSForeignReceiverArrayRequireNonnilObjectAtIndex(obj, i);
		buffer->objects[i] = objc_retain(obj);
		++i;
	}

	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:buffer];
}

+ (instancetype)array
{
	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:NSArrayBufferCreate(0)];
}

+ (instancetype)arrayWithObjects:(id)firstObject, ...
{
	_NSRequireNonnil(firstObject);

	__builtin_va_list arguments;
	__builtin_va_start(arguments, firstObject);

	NSArrayBuffer *const buffer = NSArrayBufferCreate(4);
	buffer->objects[0] = objc_retain(firstObject);
	NSUInteger count = 1;

	/* TODO: is using __unsafe_unretained the right thing to do here? */
	id __unsafe_unretained obj;
	while ((obj = __builtin_va_arg(arguments, id)) != nil) {
		/* We don't check for reaching maximum capacity, as hitting a page fault is much more likely. */
		NSArrayBufferReserve(buffer, count + 1);
		buffer->objects[count++] = objc_retain(obj);
	}

	__builtin_va_end(arguments);
	buffer->count = count;

	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:buffer];
}

+ (instancetype)arrayWithCapacity:(NSUInteger)numItems
{
	return [[self alloc] initWithCapacity:numItems];
}

- (instancetype)initWithArray:(NSArray *)array copyItems:(bool)shouldCopy
{
	_NSMutableArrayRejectReinitialization();
}

- (instancetype)initWithObjects:(id __unsafe_unretained _Nonnull const [_Nonnull])objects
		count:(NSUInteger)count
{
	return self;
}

- (instancetype)initWithObjects:(id)firstObject, ...
{
	_NSMutableArrayRejectReinitialization();
}

- (instancetype)initWithCapacity:(NSUInteger)numItems
{
	_NSMutableArrayRejectReinitialization();
}

- (NSUInteger)count
{
	_NSMutableArrayRejectInvocation();
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	_NSMutableArrayRejectInvocation();
}

#pragma mark - Mutators

- (void)addObject:(id)anObject NS_NORETURN
{
	_NSMutableArrayRejectInvocation();
}

- (void)addObjectsFromArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	NSArrayRepresentation source = _NSArrayGetRepresentation(otherArray);
	if (source.count == 0)
		return;

	NSUInteger const oldCount = self.count;
	NSUInteger newCount;
	if (__builtin_add_overflow(oldCount, source.count, &newCount) || newCount > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

	/* If this method implementation is called, the receiver is generic. Verify all objects within self's copy. */
	if ((uintptr_t)otherArray == (uintptr_t)self) {
		NSArray *copy = [self copy];
		NSUInteger i = 0;
		for (id __unsafe_unretained obj in copy) {
			_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, obj, i); /* otherArray is just a name. */
			[self addObject:obj];
		}

		return;
	}

	if (source.objects != nullptr) {
		for (NSUInteger i = 0; i < source.count; ++i)
			[self addObject:source.objects[i]];
	} else {
		for (NSUInteger i = 0; i < source.count; ++i) {
			id __unsafe_unretained obj = otherArray[i];
			_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, obj, i);
			[self addObject:obj];
		}
	}
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)index NS_NORETURN
{
	_NSMutableArrayRejectInvocation();
}

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

	NSUInteger const oldCount = self.count;
	NSUInteger newCount;
	if (__builtin_add_overflow(oldCount, source.count, &newCount) || newCount > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

	NSRange const oneRange = indexRep.rangeCount == 1 ? indexRep.r.range : NSRangeZero;
	NSRange const *const ranges = indexRep.rangeCount == 1 ? &oneRange : indexRep.r.ranges;
	if (NSRangeMax(ranges[indexRep.rangeCount - 1]) > newCount)
		_NSRaiseException(MethodContext, NSRangeException,
			@"'indexes' extends beyond insertion bound of %lu.", newCount);

	NSArray *sourceArray = objects;
	if ((uintptr_t)objects == (uintptr_t)self) {
		sourceArray = [self copy];
		source = _NSArrayGetRepresentation(sourceArray);
	}

	NSUInteger sourceIndex = 0;
	for (NSUInteger i = 0; i < indexRep.rangeCount; ++i) {
		NSRange const indexRange = ranges[i];
		NSUInteger const indexRangeEnd = NSRangeMax(indexRange);

		for (NSUInteger insertionIndex = indexRange.location; insertionIndex < indexRangeEnd;
		     ++insertionIndex, ++sourceIndex) {
			id __unsafe_unretained object;

			if (source.objects != nullptr)
				object = source.objects[sourceIndex];
			else {
				object = sourceArray[sourceIndex];
				_NSForeignArrayRequireNonnilObjectAtIndex(sourceArray, object, sourceIndex);
			}

			[self insertObject:object atIndex:insertionIndex];
		}
	}
}

- (void)exchangeObjectAtIndex:(NSUInteger)firstIndex withObjectAtIndex:(NSUInteger)secondIndex
{
	NSUInteger const count = self.count;
	_NSArrayRequireIndexWithinBounds(firstIndex, count);
	_NSArrayRequireIndexWithinBounds(secondIndex, count);

	if (firstIndex == secondIndex)
		return;

	id firstObject = self[firstIndex];
	id secondObject = self[secondIndex];
	_NSForeignReceiverArrayRequireNonnilObjectAtIndex(firstObject, firstIndex);
	_NSForeignReceiverArrayRequireNonnilObjectAtIndex(secondObject, secondIndex);

	self[firstIndex] = secondObject;
	self[secondIndex] = firstObject;
}

- (void)removeObject:(id)anObject
{
	if (anObject == nil)
		return;

	id needle = anObject;
	NSUInteger count = self.count;
	NSUInteger index = 0;

	while (index < count) {
		id<NSObject> object = self[index];

		if ([object isEqual:needle]) {
			[self removeObjectAtIndex:index];
			--count;
		} else
			++index;
	}
}

- (void)removeObject:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, self.count);

	if (anObject == nil || range.length == 0)
		return;

	id needle = anObject;
	NSUInteger remaining = range.length;
	NSUInteger index = range.location;

	while (remaining > 0) {
		id<NSObject> object = self[index];

		if ([object isEqual:needle])
			[self removeObjectAtIndex:index];
		else
			++index;

		--remaining;
	}
}

- (void)removeObjectIdenticalTo:(id)anObject
{
	if (anObject == nil)
		return;

	id needle = anObject;
	NSUInteger count = self.count;
	NSUInteger index = 0;

	while (index < count) {
		id object = self[index];

		if ((uintptr_t)object == (uintptr_t)needle) {
			[self removeObjectAtIndex:index];
			--count;
		} else
			++index;
	}
}

- (void)removeObjectIdenticalTo:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, self.count);

	if (anObject == nil || range.length == 0)
		return;

	id needle = anObject;
	NSUInteger remaining = range.length;
	NSUInteger index = range.location;

	while (remaining > 0) {
		id object = self[index];

		if ((uintptr_t)object == (uintptr_t)needle)
			[self removeObjectAtIndex:index];
		else
			++index;

		--remaining;
	}
}

- (void)removeObjectAtIndex:(NSUInteger)index NS_NORETURN
{
	_NSMutableArrayRejectInvocation();
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes
{
	_NSRequireNonnil(indexes);

	NSIndexSetRepresentation const rep = _NSIndexSetGetRepresentation(indexes);
	if (rep.count == 0)
		return;

	NSUInteger const count = self.count;
	NSRange const oneRange = rep.rangeCount == 1 ? rep.r.range : NSRangeZero;
	NSRange const *const ranges = rep.rangeCount == 1 ? &oneRange : rep.r.ranges;
	if (NSRangeMax(ranges[rep.rangeCount - 1]) > count)
		_NSRaiseException(MethodContext, NSRangeException,
			@"'indexes' extends beyond array count of %lu.", count);

	for (NSUInteger i = rep.rangeCount; i > 0; --i) {
		NSRange const range = ranges[i - 1];

		for (NSUInteger j = range.length; j > 0; --j)
			[self removeObjectAtIndex:range.location + j - 1];
	}
}

- (void)removeObjectsInRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, self.count);

	for (NSUInteger i = range.length; i > 0; --i)
		[self removeObjectAtIndex:range.location + i - 1];
}

- (void)removeObjectsInArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	NSUInteger count = self.count;
	if (count == 0)
		return;

	if ((uintptr_t)otherArray == (uintptr_t)self) {
		[self removeAllObjects];
		return;
	}

	NSArrayRepresentation const source = _NSArrayGetRepresentation(otherArray);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(otherArray, source.count);

	if (source.count == 0)
		return;

	NSUInteger index = 0;
	while (index < count) {
		id<NSObject> object = self[index];
		bool remove = false;

		for (NSUInteger i = 0; i < source.count; ++i) {
			id __unsafe_unretained candidate;

			if (source.objects != nullptr)
				candidate = source.objects[i];
			else {
				candidate = otherArray[i];
				_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, candidate, i);
			}

			if ([object isEqual:candidate]) {
				remove = true;
				break;
			}
		}

		if (remove) {
			[self removeObjectAtIndex:index];
			--count;
		} else
			++index;
	}
}

- (void)removeLastObject NS_NORETURN
{
	_NSMutableArrayRejectInvocation();
}

- (void)removeAllObjects
{
	NSUInteger count = self.count;

	while (count > 0) {
		[self removeLastObject];
		--count;
	}
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject NS_NORETURN
{
	_NSMutableArrayRejectInvocation();
}

- (void)replaceObjectsAtIndexes:(NSIndexSet *)indexes withObjects:(NSArray *)objects
{
	_NSRequireNonnil(indexes);
	_NSRequireNonnil(objects);

	NSIndexSetRepresentation const indexRep = _NSIndexSetGetRepresentation(indexes);
	NSArrayRepresentation const source = _NSArrayGetRepresentation(objects);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(objects, source.count);

	if (source.count != indexRep.count)
		_NSRaiseException(MethodContext, NSInvalidArgumentException,
			@"'objects' count of %lu differs from 'indexes' count of %lu.",
			source.count, indexRep.count);

	if (source.count == 0)
		return;

	NSUInteger const count = self.count;
	NSRange const oneRange = indexRep.rangeCount == 1 ? indexRep.r.range : NSRangeZero;
	NSRange const *const ranges = indexRep.rangeCount == 1 ? &oneRange : indexRep.r.ranges;
	if (NSRangeMax(ranges[indexRep.rangeCount - 1]) > count)
		_NSRaiseException(MethodContext, NSRangeException,
			@"'indexes' extends beyond array count of %lu.", count);

	/* Equal counts and distinct in-bounds indexes mean self supplies the same complete sequence. */
	if ((uintptr_t)objects == (uintptr_t)self)
		return;

	NSUInteger sourceIndex = 0;
	for (NSUInteger i = 0; i < indexRep.rangeCount; ++i) {
		NSRange const indexRange = ranges[i];
		NSUInteger const indexRangeEnd = NSRangeMax(indexRange);

		for (NSUInteger replacementIndex = indexRange.location; replacementIndex < indexRangeEnd;
		     ++replacementIndex, ++sourceIndex) {
			id __unsafe_unretained object;

			if (source.objects != nullptr)
				object = source.objects[sourceIndex];
			else {
				object = objects[sourceIndex];
				_NSForeignArrayRequireNonnilObjectAtIndex(objects, object, sourceIndex);
			}

			self[replacementIndex] = object;
		}
	}
}

- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	NSUInteger const oldCount = self.count;
	_NSRangeWithinUpperBound(range, oldCount);

	NSArrayRepresentation source = _NSArrayGetRepresentation(otherArray);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(otherArray, source.count);

	NSUInteger newCount;
	if (__builtin_add_overflow(oldCount - range.length, source.count, &newCount) ||
	    newCount > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");
	(void)newCount;

	if ((uintptr_t)otherArray == (uintptr_t)self && range.location == 0 && range.length == oldCount)
		return;

	NSArray *sourceArray = otherArray;
	if ((uintptr_t)otherArray == (uintptr_t)self) {
		sourceArray = [self copy];
		source = _NSArrayGetRepresentation(sourceArray);
	}

	NSUInteger const replaceCount = MIN(range.length, source.count);
	for (NSUInteger i = 0; i < replaceCount; ++i) {
		id __unsafe_unretained object;

		if (source.objects != nullptr)
			object = source.objects[i];
		else {
			object = sourceArray[i];
			_NSForeignArrayRequireNonnilObjectAtIndex(sourceArray, object, i);
		}

		self[range.location + i] = object;
	}

	if (source.count > range.length) {
		for (NSUInteger i = range.length; i < source.count; ++i) {
			id __unsafe_unretained object;

			if (source.objects != nullptr)
				object = source.objects[i];
			else {
				object = sourceArray[i];
				_NSForeignArrayRequireNonnilObjectAtIndex(sourceArray, object, i);
			}

			[self insertObject:object atIndex:range.location + i];
		}
	} else {
		for (NSUInteger i = range.length; i > source.count; --i)
			[self removeObjectAtIndex:range.location + i - 1];
	}
}

- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray *)otherArray range:(NSRange)otherRange
{
	_NSRequireNonnil(otherArray);

	NSUInteger const oldCount = self.count;
	_NSRangeWithinUpperBound(range, oldCount);

	NSArrayRepresentation source = _NSArrayGetRepresentation(otherArray);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(otherArray, source.count);
	_NSRangeWithinUpperBound(otherRange, source.count);

	NSUInteger newCount;
	if (__builtin_add_overflow(oldCount - range.length, otherRange.length, &newCount) ||
	    newCount > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");
	(void)newCount;

	if ((uintptr_t)otherArray == (uintptr_t)self && range.length == otherRange.length) {
		if (range.location == otherRange.location)
			return;

		if (range.location < otherRange.location) {
			for (NSUInteger i = 0; i < range.length; ++i) {
				id object = self[otherRange.location + i];
				_NSForeignReceiverArrayRequireNonnilObjectAtIndex(object, otherRange.location + i);
				self[range.location + i] = object;
			}
		} else {
			for (NSUInteger i = range.length; i > 0; --i) {
				NSUInteger const offset = i - 1;
				id object = self[otherRange.location + offset];
				_NSForeignReceiverArrayRequireNonnilObjectAtIndex(object,
					otherRange.location + offset);
				self[range.location + offset] = object;
			}
		}

		return;
	}

	NSArray *sourceArray = otherArray;
	NSUInteger sourceBase = otherRange.location;

	if ((uintptr_t)otherArray == (uintptr_t)self && otherRange.length > 0) {
		if (otherRange.location == 0 && otherRange.length == oldCount)
			sourceArray = [self copy];
		else
			sourceArray = [self subarrayWithRange:otherRange];

		source = _NSArrayGetRepresentation(sourceArray);
		sourceBase = 0;
	}

	NSUInteger const replaceCount = MIN(range.length, otherRange.length);
	for (NSUInteger i = 0; i < replaceCount; ++i) {
		NSUInteger const sourceIndex = sourceBase + i;
		id __unsafe_unretained object;

		if (source.objects != nullptr)
			object = source.objects[sourceIndex];
		else {
			object = sourceArray[sourceIndex];
			_NSForeignArrayRequireNonnilObjectAtIndex(sourceArray, object, sourceIndex);
		}

		self[range.location + i] = object;
	}

	if (otherRange.length > range.length) {
		for (NSUInteger i = range.length; i < otherRange.length; ++i) {
			NSUInteger const sourceIndex = sourceBase + i;
			id __unsafe_unretained object;

			if (source.objects != nullptr)
				object = source.objects[sourceIndex];
			else {
				object = sourceArray[sourceIndex];
				_NSForeignArrayRequireNonnilObjectAtIndex(sourceArray, object, sourceIndex);
			}

			[self insertObject:object atIndex:range.location + i];
		}
	} else {
		for (NSUInteger i = range.length; i > otherRange.length; --i)
			[self removeObjectAtIndex:range.location + i - 1];
	}
}

- (void)setObject:(id)anObject atIndexedSubscript:(NSUInteger)index
{
	_NSRequireNonnil(anObject);

	NSUInteger const count = self.count;
	if (index > count)
		_NSRaiseException(MethodContext, NSRangeException,
			@"'index' with value %lu extends beyond insertion bound of %lu.", index, count);

	if (index == count)
		[self addObject:anObject];
	else
		[self replaceObjectAtIndex:index withObject:anObject];
}

- (void)setArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	if ((uintptr_t)otherArray == (uintptr_t)self)
		return;

	NSArrayRepresentation const source = _NSArrayGetRepresentation(otherArray);
	if (source.objects == nullptr)
		_NSForeignArrayRequireCountWithinBounds(otherArray, source.count);

	NSUInteger const oldCount = self.count;
	NSUInteger const replaceCount = MIN(oldCount, source.count);

	for (NSUInteger i = 0; i < replaceCount; ++i) {
		id __unsafe_unretained object;

		if (source.objects != nullptr)
			object = source.objects[i];
		else {
			object = otherArray[i];
			_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, object, i);
		}

		self[i] = object;
	}

	if (source.count > oldCount) {
		for (NSUInteger i = oldCount; i < source.count; ++i) {
			id __unsafe_unretained object;

			if (source.objects != nullptr)
				object = source.objects[i];
			else {
				object = otherArray[i];
				_NSForeignArrayRequireNonnilObjectAtIndex(otherArray, object, i);
			}

			[self addObject:object];
		}
	} else {
		for (NSUInteger i = oldCount; i > source.count; --i)
			[self removeLastObject];
	}
}

@end

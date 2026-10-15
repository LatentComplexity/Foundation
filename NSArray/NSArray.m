
#import <FoundationPrivate/NSArray/NSArray.h>

@implementation NSArray

unsigned __int128 _NSArrayHashKey;
NSUInteger _NSZeroArrayHash;

Class _NSArrayClass;
Class _NSArrayTemplateClass;
Class _NSZeroArrayClass;
Class _NSSingleEntryArrayClass;
Class _NSInlineArrayClass;
Class _NSSubrangeArrayClass;
Class _NSMutableArrayClass;
Class _NSMutableArrayTemplateClass;
Class _NSMutableInlineArrayClass;

static NSArrayTemplate *_NSArrayTemplateInstance = nil;
NSZeroArray *_NSZeroArrayInstance = nil;
NSZeroArrayEnumerator *_NSZeroArrayEnumeratorInstance = nil;

+ (void)initialize
{
	static NSCallOnceState s = {};

	if (self == [NSArray class] || self == [NSMutableArray class])
		NSCallOnce(&s, ^{
			NSRandomBytes(&_NSArrayHashKey, sizeof(_NSArrayHashKey));
			_NSZeroArrayHash = NSSipHash((NSUInteger[]){ 0 }, sizeof(NSUInteger), _NSArrayHashKey);
			_NSArrayClass = [NSArray class];
			_NSArrayTemplateClass = [NSArrayTemplate class];
			_NSZeroArrayClass = [NSZeroArray class];
			_NSSingleEntryArrayClass = [NSSingleEntryArray class];
			_NSInlineArrayClass = [NSInlineArray class];
			_NSSubrangeArrayClass = [NSSubrangeArray class];
			_NSMutableArrayClass = [NSMutableArray class];
			_NSMutableArrayTemplateClass = [NSMutableArray class];
			_NSMutableInlineArrayClass = [NSMutableInlineArray class];

			_NSArrayTemplateInstance = [NSArrayTemplate alloc];
			_NSZeroArrayInstance = [NSZeroArray alloc];
			_NSZeroArrayEnumeratorInstance = [NSZeroArrayEnumerator alloc];
		});
}

+ (instancetype)alloc
{
	if (self == _NSArrayClass)
		return _NSArrayTemplateInstance;

	return class_createInstance(self, 0);
}

- (id)copy
{
	return self;
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
	return _NSZeroArrayInstance;
}

+ (instancetype)arrayWithArray:(NSArray *)array
{
	return [[self alloc] initWithArray:array];
}

+ (instancetype)arrayWithObject:(id)anObject
{
	_NSRequireNonnil(anObject);

	return (id)[[NSSingleEntryArray alloc] _initWithObject:anObject];
}

+ (instancetype)arrayWithObjects:(id __unsafe_unretained _Nonnull const [_Nonnull])objects
		count:(NSUInteger)count
{
	return [[self alloc] initWithObjects:objects count:count];
}

+ (instancetype)arrayWithObjects:(id)firstObject, ...
{
	_NSRequireNonnil(firstObject);

	__builtin_va_list arguments;
	__builtin_va_start(arguments, firstObject);

	/* TODO: is using __unsafe_unretained the right thing to do here? */
	id __unsafe_unretained secondObject = __builtin_va_arg(arguments, id);
	if (secondObject == nil)
		return [[NSSingleEntryArray alloc] _initWithObject:firstObject];

	NSArrayBuffer *const buffer = NSArrayBufferCreate(4);
	buffer->objects[0] = objc_retain(firstObject);
	buffer->objects[1] = objc_retain(secondObject);
	NSUInteger count = 2;

	id __unsafe_unretained obj;
	while ((obj = __builtin_va_arg(arguments, id)) != nil) {
		/* We don't check for reaching maximum capacity, as hitting a page fault is much more likely. */
		NSArrayBufferReserve(buffer, count + 1);
		buffer->objects[count++] = objc_retain(obj);
	}

	__builtin_va_end(arguments);
	buffer->count = count;

	return (id)[[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (instancetype)initWithArray:(NSArray *)array
{
	_NSArrayRejectReinitialization();
}

- (instancetype)initWithArray:(NSArray *)array copyItems:(bool)shouldCopy
{
	_NSArrayRejectReinitialization();
}

- (instancetype)initWithObjects:(id __unsafe_unretained _Nonnull const [_Nonnull])objects
		count:(NSUInteger)count
{
	return self;
}

- (instancetype)initWithObjects:(id)firstObject, ...
{
	_NSArrayRejectReinitialization();
}

- (NSUInteger)count
{
	_NSArrayRejectInvocation();
}

- (nullable id)firstObject
{
	if (self.count == 0)
		return nil;

	return self[0];
}

- (nullable id)lastObject
{
	NSUInteger const count = self.count;
	if (count == 0)
		return nil;

	return self[count - 1];
}

- (NSArray *)arrayByAddingObject:(id)anObject
{
	_NSRequireNonnil(anObject);
	NSUInteger const count = self.count;

	if (count == 0)
		return [[NSSingleEntryArray alloc] _initWithObject:anObject];

	if (count >= NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

	NSUInteger const newCount = count + 1;
	NSArrayBuffer *const buffer = NSArrayBufferCreate(newCount);
	buffer->count = newCount;

	NSUInteger i = 0;
	for (id __unsafe_unretained obj in self) {
		_NSForeignArrayRequireNonnilObjectAtIndex(self, obj, i);
		buffer->objects[i++] = objc_retain(obj);
	}

	buffer->objects[count] = objc_retain(anObject);

	return [[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (NSArray *)arrayByAddingObjectsFromArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	return _NSArrayByAddingObjectsFromArray(((NSArrayRepresentation) {
		self, nullptr, nullptr, self.count, false
	}), otherArray);
}

- (NSArray *)subarrayWithRange:(NSRange)range
{
	NSUInteger const count = self.count;

	if (range.location == 0 && range.length == count)
		return self;

	_NSRangeWithinUpperBound(range, count);

	/* Return specialized subclasses for zero- and single-length ranges. */
	if (range.length == 0)
		return _NSZeroArrayInstance;

	if (range.length == 1) {
		id __unsafe_unretained obj = self[range.location];
		_NSForeignArrayRequireNonnilObjectAtIndex(self, obj, range.location);
		return [[NSSingleEntryArray alloc] _initWithObject:obj];
	}

	/* Create a buffer holding objects in the desired range. */
	NSArrayBuffer *const buffer = NSArrayBufferCreate(range.length);
	buffer->count = range.length;

	for (NSUInteger i = range.location, k = 0; i < NSRangeMax(range); ++i) {
		id __unsafe_unretained obj = self[i];
		_NSForeignArrayRequireNonnilObjectAtIndex(self, obj, i);
		buffer->objects[k++] = objc_retain(obj);
	}

	return [[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexSet
{
	_NSRequireNonnil(indexSet);

	return _NSArrayObjectsAtIndexes(((NSArrayRepresentation) {
		self, nullptr, nullptr, self.count, false
	}), _NSIndexSetGetRepresentation(indexSet));
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	_NSArrayRejectInvocation();
}

- (void)getObjects:(id _Nonnull __unsafe_unretained [_Nonnull])objects range:(NSRange)range
{
	_NSRequireNonnullptr(objects);
	_NSRangeWithinUpperBound(range, self.count);

	for (NSUInteger i = range.location, j = 0; i < NSRangeMax(range); ++i) {
		id __unsafe_unretained obj = self[i];
		_NSForeignArrayRequireNonnilObjectAtIndex(self, obj, i);
		objects[j++] = obj;
	}
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

- (void)makeObjectsPerformSelector:(SEL)aSelector
{
	_NSRequireNonnullptr(aSelector);

	NSUInteger i = 0;
	for (id<NSObject> __unsafe_unretained obj in self) {
		_NSForeignArrayRequireNonnilObjectAtIndex(self, obj, i);
		[obj performSelector:aSelector];
		++i;
	}
}

- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(nullable id)anObject
{
	_NSRequireNonnullptr(aSelector);

	NSUInteger i = 0;
	for (id<NSObject> __unsafe_unretained obj in self) {
		_NSForeignArrayRequireNonnilObjectAtIndex(self, obj, i);
		[obj performSelector:aSelector withObject:anObject];
		++i;
	}
}

#pragma clang diagnostic pop

- (NSUInteger)indexOfObject:(id)anObject
{
	if (anObject == nil)
		return NSNotFound;

	/* No need to check for nil objects in receiver. */
	NSUInteger i = 0;
	for (id<NSObject> __unsafe_unretained obj in self) {
		if ([obj isEqual:anObject])
			return i;
		++i;
	}

	return NSNotFound;
}

- (NSUInteger)indexOfObject:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, self.count);

	if (anObject == nil)
		return NSNotFound;

	/* No need to check for nil objects in receiver. */
	for (NSUInteger i = range.location; i < NSRangeMax(range); ++i) {
		id<NSObject> __unsafe_unretained obj = self[i];
		if ([obj isEqual:anObject])
			return i;
	}

	return NSNotFound;
}

- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject
{
	if (anObject == nil)
		return NSNotFound;

	/* No need to check for nil objects in receiver. */
	NSUInteger i = 0;
	for (id<NSObject> __unsafe_unretained obj in self) {
		if ((uintptr_t)obj == (uintptr_t)anObject)
			return i;
		++i;
	}

	return NSNotFound;
}

- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)range
{
	_NSRangeWithinUpperBound(range, self.count);

	if (anObject == nil)
		return NSNotFound;

	/* No need to check for nil objects in receiver. */
	for (NSUInteger i = range.location; i < NSRangeMax(range); ++i) {
		id<NSObject> __unsafe_unretained obj = self[i];
		if ((uintptr_t)obj == (uintptr_t)anObject)
			return i;
	}

	return NSNotFound;
}

- (NSUInteger)indexOfObjectPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	NSUInteger const count = self.count;

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, nullptr, count, false
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, count), 1, count
	}), NSEnumerationNoOptions, predicate);
}

- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	NSUInteger const count = self.count;

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, nullptr, count, false
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, count), 1, count
	}), options, predicate);
}

- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, nullptr, self.count, false
	}), _NSIndexSetGetRepresentation(indexSet), options, predicate);
}

- (NSIndexSet *)indexesOfObjectsPassingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(predicate);

	NSUInteger const count = self.count;

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, nullptr, self.count, false
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, count), 1, count
	}), NSEnumerationNoOptions, predicate);
}

- (NSIndexSet *)indexesOfObjectsWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	NSUInteger const count = self.count;

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, nullptr, self.count, false
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, count), 1, count
	}), options, predicate);
}

- (NSIndexSet *)indexesOfObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(id, NSUInteger, bool *))predicate
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(predicate);

	return _NSArrayIndexesOfObjectAtIndexesWithOptionsPassingTest(((NSArrayRepresentation) {
		self, nullptr, nullptr, self.count, false
	}), _NSIndexSetGetRepresentation(indexSet), options, predicate);
}

- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(block);

	NSUInteger const count = self.count;

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, nullptr, nullptr, count, false
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, count), 1, count
	}), NSEnumerationNoOptions, block);
}

- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	NSUInteger const count = self.count;

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, nullptr, nullptr, count, false
	}), ((NSIndexSetRepresentation) {
		nil, Nil, .r.range = NSRangeMake(0, count), 1, count
	}), options, block);
}

- (void)enumerateObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(id, NSUInteger, bool *))block
{
	_NSRequireNonnil(indexSet);
	_NSEnumerationOptionsCheck(options);
	_NSRequireNonnil(block);

	_NSArrayEnumerateObjectsAtIndexesWithOptionsUsingBlock(((NSArrayRepresentation) {
		self, nullptr, nullptr, self.count, false
	}), _NSIndexSetGetRepresentation(indexSet), options, block);
}

- (bool)containsObject:(id)anObject
{
	if (anObject == nil)
		return false;

	/* No need to check for nil objects in receiver. */
	for (id<NSObject> __unsafe_unretained obj in self)
		if ([obj isEqual:anObject])
			return true;

	return false;
}

- (NSUInteger)hash
{
	NSUInteger const count = self.count;

	if (count == 0)
		return _NSZeroArrayHash;

	NSSipHashContext context;
	NSUInteger hash;

	NSSipHashContextInit(&context, _NSArrayHashKey);
	NSSipHashWithContext(&context, (NSUInteger[]){ count }, sizeof(NSUInteger));

	for (id<NSObject> __unsafe_unretained obj in self)
		NSSipHashWithContext(&context, (NSUInteger[]){ obj.hash }, sizeof(NSUInteger));

	NSSipHashWithContextFinalize(&context, &hash);

	return hash;
}

- (bool)isEqualToArray:(NSArray *)otherArray
{
	_NSRequireNonnil(otherArray);

	if ((uintptr_t)self == (uintptr_t)otherArray)
		return true;

	Class const c = object_getClass(otherArray);
	NSUInteger const count = self.count;
	id __unsafe_unretained const *otherObjects;
	NSUInteger otherCount;

	if (c == _NSZeroArrayClass)
		return count == 0;
	else if (c == _NSSingleEntryArrayClass)
		return count == 1 && [(id<NSObject>)self[0]
			isEqual:((__bridge NSSingleEntryArrayLayout *)otherArray)->anObject];
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

	if (count != otherCount)
		return false;

	/* Messaging nil will naturally return false. */
	NSUInteger i = 0;
	if (otherObjects != nullptr) {
		for (id __unsafe_unretained obj in self)
			if ([(id<NSObject>)obj isEqual:otherObjects[i++]] == false)
				return false;
	} else {
		for (id __unsafe_unretained obj in self)
			if ([(id<NSObject>)obj isEqual:otherArray[i++]] == false)
				return false;
	}

	return true;
}

- (bool)isEqual:(id)anObject
{
	if ((uintptr_t)self == (uintptr_t)anObject)
		return true;

	if ([(id<NSObject>)anObject isKindOfClass:_NSArrayClass])
		return [self isEqualToArray:(NSArray *)anObject];

	return false;
}

- (NSEnumerator *)objectEnumerator
{
	return [NSArrayEnumerator _enumeratorWithArray:self];
}

- (NSEnumerator *)reverseObjectEnumerator
{
	return [NSArrayReverseEnumerator _enumeratorWithArray:self];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	NSUInteger index = state->state;
	NSUInteger const count = self.count;
	NSUInteger filled = 0;

	while (filled < stackBufferCapacity && index < count)
		stackBuffer[filled++] = self[index++];

	state->mutationsPtr = (unsigned long *)(uintptr_t)self;
	state->itemsPtr = stackBuffer;
	state->state = index;

	return filled;
}

@end

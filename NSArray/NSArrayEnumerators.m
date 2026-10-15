
#import <FoundationPrivate/NSArray/NSArray.h>

#pragma mark - Generic Enumerator

@implementation NSArrayEnumerator {
	NSArray *_array;
	NSUInteger _cursor;
	NSUInteger _count;
}

+ (instancetype)_enumeratorWithArray:(NSArray *)array OBJC_DIRECT
{
	NSUInteger arrayCount = array.count;

	/* We don't trust external array instances. */
	if (arrayCount > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"array overflow.");

	NSArrayEnumerator *obj = class_createInstance(self, 0);
	obj->_array = array;
	obj->_cursor = 0;
	obj->_count = arrayCount;

	return obj;
}

- (nullable id)nextObject
{
	return _cursor >= _count ? _array = nil : _array[_cursor++];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	NSUInteger const remaining = _count - _cursor;

	if (remaining == 0) {
		_array = nil;
		return 0;
	}

	NSUInteger const batch = MIN(remaining, stackBufferCapacity);

	[_array getObjects:stackBuffer range:NSRangeMake(_cursor, batch)];
	_cursor += batch;

	state->mutationsPtr = (unsigned long *)(uintptr_t)self;
	state->itemsPtr = stackBuffer;

	return batch;
}

@end

@implementation NSArrayReverseEnumerator {
	NSArray *_array;
	NSUInteger _cursor;
	NSUInteger _count;
}

+ (instancetype)_enumeratorWithArray:(NSArray *)array OBJC_DIRECT
{
	NSUInteger arrayCount = array.count;

	/* We don't trust external array instances. */
	if (arrayCount > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"buffer overflow.");

	NSArrayReverseEnumerator *obj = class_createInstance(self, 0);
	obj->_array = array;
	obj->_cursor = arrayCount;
	obj->_count = arrayCount;

	return obj;
}

- (nullable id)nextObject
{
	return _cursor == 0 ? _array = nil : _array[--_cursor];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	if (_cursor == 0) {
		_array = nil;
		return 0;
	}

	NSUInteger const batch = MIN(_cursor, stackBufferCapacity);

	for (NSUInteger i = 0; i < batch; ++i)
		stackBuffer[i] = _array[--_cursor];

	state->mutationsPtr = (unsigned long *)(uintptr_t)self;
	state->itemsPtr = stackBuffer;

	return batch;
}

@end

#pragma mark - Zero Array Enumerator

@implementation NSZeroArrayEnumerator

- (nullable id)nextObject
{
	return nil;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	return 0;
}

@end

#pragma mark - Single Entry Enumerator

@implementation NSSingleEntryArrayEnumerator {
	id<NSObject> _anObject;
	bool _isConsumed;
}

+ (instancetype)_enumeratorWithObject:(id)anObject OBJC_DIRECT
{
	NSSingleEntryArrayEnumerator *obj = class_createInstance(self, 0);
	obj->_anObject = anObject;
	obj->_isConsumed = false;

	return obj;
}

- (nullable id)nextObject
{
	if (_isConsumed == false) {
		id obj = _anObject;
		_anObject = nil;
		_isConsumed = true;
		return obj;
	}

	_anObject = nil;
	return nil;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	if (stackBufferCapacity == 0)
		return 0;

	if (_isConsumed == false) {
		stackBuffer[0] = _anObject;
		state->state = 1;
		state->mutationsPtr = (unsigned long *)(uintptr_t)self;
		state->itemsPtr = stackBuffer;
		_isConsumed = true;
		return 1;
	}

	_anObject = nil;
	return 0;
}

@end

#pragma mark - Inline Array Enumerator

@implementation NSInlineArrayEnumerator {
	NSArrayBuffer *_Nullable _buffer;
	NSUInteger _cursor;
}

+ (instancetype)_enumeratorWithBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT
{
	NSInlineArrayEnumerator *obj = class_createInstance(self, 0);
	obj->_buffer = NSArrayBufferRetain(buffer);
	obj->_cursor = 0;

	return obj;
}

- (nullable id)nextObject
{
	if (_buffer == nullptr)
		return nil;

	if (_cursor >= _buffer->count) {
		NSArrayBufferRelease(_buffer);
		_buffer = nullptr;
		return nil;
	}

	return _buffer->objects[_cursor++];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	(void)stackBuffer;
	(void)stackBufferCapacity;

	/* A null buffer means one of the two enumeration methods has exhausted the array. */
	if (_buffer == nullptr)
		return 0;

	/* This method has exhausted the array; null the buffer so both methods can give up. */
	if (state->extra[0] == 1) {
		NSArrayBufferRelease(_buffer);
		_buffer = nullptr;
		return 0;
	}

	/* We have more objects to iterate through; batch them all in one go. */
	state->mutationsPtr = (unsigned long *)(uintptr_t)self;
	state->itemsPtr = _buffer->objects + _cursor;
	state->extra[0] = 1;

	return _buffer->count - _cursor;
}

- (void)dealloc
{
	if (_buffer != nullptr)
		NSArrayBufferRelease(_buffer);
}

@end

@implementation NSInlineArrayReverseEnumerator {
	NSArrayBuffer *_Nullable _buffer;
	NSUInteger _cursor;
}

+ (instancetype)_enumeratorWithBuffer:(NSArrayBuffer *)buffer OBJC_DIRECT
{
	NSInlineArrayReverseEnumerator *obj = class_createInstance(self, 0);
	obj->_buffer = NSArrayBufferRetain(buffer);
	obj->_cursor = buffer->count;

	return obj;
}

- (nullable id)nextObject
{
	if (_buffer == nullptr)
		return nil;

	if (_cursor == 0) {
		NSArrayBufferRelease(_buffer);
		_buffer = nullptr;
		return nil;
	}

	return _buffer->objects[--_cursor];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	(void)stackBuffer;
	(void)stackBufferCapacity;

	/* A null buffer means one of the two enumeration methods has exhausted the array. */
	if (_buffer == nullptr)
		return 0;

	/* This method has exhausted the array; null the buffer so both methods can give up. */
	if (_cursor == 0) {
		NSArrayBufferRelease(_buffer);
		_buffer = nullptr;
		return 0;
	}

	/* Load this batch in reverse order into the stack buffer. */
	NSUInteger const batch = MIN(_cursor, stackBufferCapacity);
	for (NSUInteger i = 0; i < batch; ++i)
		stackBuffer[i] = _buffer->objects[--_cursor];

	state->mutationsPtr = (unsigned long *)(uintptr_t)self;
	state->itemsPtr = stackBuffer;

	return batch;
}

- (void)dealloc
{
	if (_buffer != nullptr)
		NSArrayBufferRelease(_buffer);
}

@end

#pragma mark - Subrange Array Enumerator

@implementation NSSubrangeArrayEnumerator {
	NSArrayBuffer *_Nullable _buffer;
	NSUInteger _base;
	NSUInteger _count;
	NSUInteger _cursor;
}

+ (instancetype)_enumeratorWithBuffer:(NSArrayBuffer *)buffer base:(NSUInteger)base
		count:(NSUInteger)count OBJC_DIRECT
{
	NSSubrangeArrayEnumerator *obj = class_createInstance(self, 0);
	obj->_buffer = NSArrayBufferRetain(buffer);
	obj->_base = base;
	obj->_count = count;
	obj->_cursor = 0;

	return obj;
}

- (nullable id)nextObject
{
	if (_buffer == nullptr)
		return nil;

	if (_cursor >= _count) {
		NSArrayBufferRelease(_buffer);
		_buffer = nullptr;
		return nil;
	}

	return _buffer->objects[_base + _cursor++];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	(void)stackBuffer;
	(void)stackBufferCapacity;

	/* A null buffer means one of the two enumeration methods has exhausted the array. */
	if (_buffer == nullptr)
		return 0;

	/* This method has exhausted the array; null the buffer so both methods can give up. */
	if (state->extra[0] == 1) {
		NSArrayBufferRelease(_buffer);
		_buffer = nullptr;

		return 0;
	}

	/* The window is contiguous; return all remaining objects in one batch. */
	state->mutationsPtr = (unsigned long *)(uintptr_t)self;
	state->itemsPtr = _buffer->objects + _base + _cursor;
	state->extra[0] = 1;

	return _count - _cursor;
}

- (void)dealloc
{
	if (_buffer != nullptr)
		NSArrayBufferRelease(_buffer);
}

@end

@implementation NSSubrangeArrayReverseEnumerator {
	NSArrayBuffer *_Nullable _buffer;
	NSUInteger _base;
	NSUInteger _cursor;
}

+ (instancetype)_enumeratorWithBuffer:(NSArrayBuffer *)buffer base:(NSUInteger)base
		count:(NSUInteger)count OBJC_DIRECT
{
	NSSubrangeArrayReverseEnumerator *obj = class_createInstance(self, 0);
	obj->_buffer = NSArrayBufferRetain(buffer);
	obj->_base = base;
	obj->_cursor = count;

	return obj;
}

- (nullable id)nextObject
{
	if (_buffer == nullptr)
		return nil;

	if (_cursor == 0) {
		NSArrayBufferRelease(_buffer);
		_buffer = nullptr;
		return nil;
	}

	return _buffer->objects[_base + --_cursor];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	/* A null buffer means one of the two enumeration methods has exhausted the array. */
	if (_buffer == nullptr)
		return 0;

	/* This method has exhausted the array; null the buffer so both methods can give up. */
	if (_cursor == 0) {
		NSArrayBufferRelease(_buffer);
		_buffer = nullptr;
		return 0;
	}

	/* Load this batch in reverse order into the stack buffer. */
	NSUInteger const batch = MIN(_cursor, stackBufferCapacity);
	for (NSUInteger i = 0; i < batch; ++i)
		stackBuffer[i] = _buffer->objects[_base + --_cursor];

	state->mutationsPtr = (unsigned long *)(uintptr_t)self;
	state->itemsPtr = stackBuffer;

	return batch;
}

- (void)dealloc
{
	if (_buffer != nullptr)
		NSArrayBufferRelease(_buffer);
}

@end

#pragma mark - Mutable Array Enumerator

/*
 * Could these have been implemented holding just _array? Yes, but, I fear for my cache locality. Thus, we cache
 * _buffer in a vain attempt to avoid too much dereferencing. We retain the array object itself so that _mutations
 * remains valid if the enumerator object lives past the array object's scope.
 */

@implementation NSMutableInlineArrayEnumerator {
	NSMutableInlineArray *_array;
	NSArrayBuffer *_buffer;
	NSUInteger _cursor;
}

+ (instancetype)_enumeratorWithArray:(NSMutableInlineArray *)array OBJC_DIRECT
{
	NSMutableInlineArrayEnumerator *obj = class_createInstance(self, 0);
	obj->_array = array;
	obj->_buffer = (NSArrayBuffer *)(uintptr_t)((__bridge NSMutableInlineArrayLayout *)array)->buffer;
	obj->_cursor = 0;

	return obj;
}

- (nullable id)nextObject
{
	if (_buffer == nullptr)
		return nil;

	if (_cursor >= _buffer->count) {
		_array = nil;
		_buffer = nullptr;
		return nil;
	}

	return _buffer->objects[_cursor++];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	(void)stackBuffer;
	(void)stackBufferCapacity;

	/* A null buffer means one of the two enumeration methods has exhausted the array. */
	if (_buffer == nullptr)
		return 0;

	/* This method has exhausted the array; null the buffer so both methods can give up. */
	if (state->extra[0] == 1) {
		_array = nil;
		_buffer = nullptr;
		return 0;
	}

	/* We have more objects to iterate through; batch them all in one go. */
	state->mutationsPtr = &((__bridge NSMutableInlineArrayLayout *)_array)->mutations;
	state->itemsPtr = _buffer->objects + _cursor;
	state->extra[0] = 1;

	return _buffer->count - _cursor;
}

@end

@implementation NSMutableInlineArrayReverseEnumerator {
	NSMutableInlineArray *_array;
	NSArrayBuffer *_buffer;
	NSUInteger _cursor;
}

+ (instancetype)_enumeratorWithArray:(NSMutableInlineArray *)array OBJC_DIRECT
{
	NSMutableInlineArrayReverseEnumerator *obj = class_createInstance(self, 0);
	obj->_array = array;
	obj->_buffer = (NSArrayBuffer *)(uintptr_t)((__bridge NSMutableInlineArrayLayout *)array)->buffer;
	obj->_cursor = obj->_buffer->count;

	return obj;
}

- (nullable id)nextObject
{
	if (_buffer == nullptr)
		return nil;

	if (_cursor == 0) {
		_array = nil;
		_buffer = nullptr;
		return nil;
	}

	return _buffer->objects[--_cursor];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	(void)stackBuffer;
	(void)stackBufferCapacity;

	/* A null buffer means one of the two enumeration methods has exhausted the array. */
	if (_buffer == nullptr)
		return 0;

	/* This method has exhausted the array; null the buffer so both methods can give up. */
	if (_cursor == 0) {
		_array = nil;
		_buffer = nullptr;
		return 0;
	}

	/* Load this batch in reverse order into the stack buffer. */
	NSUInteger const batch = MIN(_cursor, stackBufferCapacity);
	for (NSUInteger i = 0; i < batch; ++i)
		stackBuffer[i] = _buffer->objects[--_cursor];

	state->mutationsPtr = &((__bridge NSMutableInlineArrayLayout *)_array)->mutations;
	state->itemsPtr = stackBuffer;

	return batch;
}

@end

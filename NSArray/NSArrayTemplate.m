
#import <FoundationPrivate/NSArray/NSArray.h>

@implementation NSArrayTemplate

- (instancetype)init
{
	return (id)_NSZeroArrayInstance;
}

- (instancetype)initWithObjects:(id __unsafe_unretained _Nonnull const [_Nonnull])objects count:(NSUInteger)count
{
	_NSRequireNonnullptr(objects);

	if (count > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"buffer overflow.");

	if (count == 0)
		return (id)_NSZeroArrayInstance;

	if (count == 1) {
		if (objects[0] == nil)
			_NSRaiseException(MethodContext, NSInvalidArgumentException, @"'objects[0]' was nil.");
		return (id)[[NSSingleEntryArray alloc] _initWithObject:objects[0]];
	}

	NSArrayBuffer *const buffer = NSArrayBufferCreate(count);
	buffer->count = count;

	for (NSUInteger i = 0; i < count; ++i) {
		if (objects[i] == nil) {
			/* Best effort cleanup. */
			free(buffer->objects);
			free(buffer);
			_NSRaiseException(MethodContext, NSInvalidArgumentException, @"'objects[%lu]' was nil.", i);
		}

		buffer->objects[i] = objc_retain(objects[i]);
	}

	return (id)[[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (instancetype)initWithObjects:(id)firstObject, ...
{
	_NSRequireNonnil(firstObject);

	__builtin_va_list arguments;
	__builtin_va_start(arguments, firstObject);

	id secondObject = __builtin_va_arg(arguments, id);
	if (secondObject == nil)
		return (id)[[NSSingleEntryArray alloc] _initWithObject:firstObject];

	NSArrayBuffer *const buffer = NSArrayBufferCreate(4);
	buffer->objects[0] = objc_retain(firstObject);
	buffer->objects[1] = objc_retain(secondObject);
	NSUInteger count = 2;

	id obj;
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
	_NSRequireNonnil(array);

	Class const c = object_getClass(array);

	if (c == _NSZeroArrayClass || c == _NSSingleEntryArrayClass || c == _NSInlineArrayClass ||
	    c == _NSSubrangeArrayClass)
		return (id)array;

	if (c == _NSMutableInlineArrayClass)
		return (id)[array copy];

	NSUInteger const count = array.count;

	if (count == 0)
		return (id)_NSZeroArrayInstance;

	if (count == 1) {
		id __unsafe_unretained obj = array[0];
		_NSForeignArrayRequireNonnilObjectAtIndex(array, obj, 0);
		return (id)[[NSSingleEntryArray alloc] _initWithObject:obj];
	}

	_NSForeignArrayRequireCountWithinBounds(array, count);

	NSArrayBuffer *const buffer = NSArrayBufferCreate(count);
	buffer->count = count;

	NSUInteger i = 0;
	for (id __unsafe_unretained obj in array) {
		_NSForeignArrayRequireNonnilObjectAtIndex(array, obj, i);
		buffer->objects[i] = objc_retain(obj);
		++i;
	}

	return (id)[[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (instancetype)initWithArray:(NSArray *)array copyItems:(bool)shouldCopy
{
	_NSRequireNonnil(array);

	Class const c = object_getClass(array);
	id<NSObject> __unsafe_unretained *objects;
	NSUInteger count;

	if (c == _NSZeroArrayClass)
		return (id)_NSZeroArrayInstance;
	else if (c == _NSSingleEntryArrayClass) {
		if (shouldCopy) {
			id __unsafe_unretained obj = ((__bridge NSSingleEntryArrayLayout *)array)->anObject;
			return (id)[[NSSingleEntryArray alloc] _initWithObject:[(id<NSCopying>)obj copy]];
		} else
			return (id)array;
	} else if (c == _NSInlineArrayClass || c == _NSMutableInlineArrayClass) {
		NSInlineArrayLayout const *const layout = (__bridge NSInlineArrayLayout *)array;
		objects = layout->buffer->objects;
		count = layout->buffer->count;
	} else if (c == _NSSubrangeArrayClass) {
		NSSubrangeArrayLayout const *const layout = (__bridge NSSubrangeArrayLayout *)array;
		objects = layout->buffer->objects + layout->base;
		count = layout->count;
	} else {
		objects = nullptr;
		count = array.count;
		_NSForeignArrayRequireCountWithinBounds(array, count);
	}

	if (shouldCopy) {
		NSArrayBuffer *const buffer = NSArrayBufferCreate(count);
		buffer->count = count;

		if (objects != nullptr) {
			for (NSUInteger i = 0; i < count; ++i)
				buffer->objects[i] = objc_retain([(id<NSCopying>)objects[i] copy]);
		} else {
			for (NSUInteger i = 0; i < count; ++i) {
				id<NSCopying> __unsafe_unretained obj = array[i];
				_NSForeignArrayRequireNonnilObjectAtIndex(array, obj, i);
				buffer->objects[i] = objc_retain([obj copy]);
			}
		}

		return (id)[[NSInlineArray alloc] _initAdoptingBuffer:buffer];
	} else {
		/* One of us. */
		if (objects != nullptr)
			return c != _NSMutableInlineArrayClass ? (id)array : (id)[array copy];
		else {
			/* We hope that no one overrides -copy and returns nil. */
			id arrayCopy = [array copy];
			if (arrayCopy == nil)
				_NSRaiseException(MethodContext, NSInvalidArgumentException,
					@"'array' returned nil from -copy.");

			return arrayCopy;
		}
	}
}

@end

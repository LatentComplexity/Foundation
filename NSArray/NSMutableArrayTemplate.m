
#import <FoundationPrivate/NSArray/NSArray.h>

@implementation NSMutableArrayTemplate

- (instancetype)init
{
	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:NSArrayBufferCreate(0)];
}

- (instancetype)initWithObjects:(id __unsafe_unretained _Nonnull const [_Nonnull])objects count:(NSUInteger)count
{
	_NSRequireNonnullptr(objects);

	if (count > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"buffer overflow.");

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

	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (instancetype)initWithObjects:(id)firstObject, ...
{
	_NSRequireNonnil(firstObject);

	NSArrayBuffer *const buffer = NSArrayBufferCreate(4);
	buffer->objects[0] = objc_retain(firstObject);
	NSUInteger count = 1;

	__builtin_va_list arguments;
	__builtin_va_start(arguments, firstObject);

	id obj;
	while ((obj = __builtin_va_arg(arguments, id)) != nil) {
		NSArrayBufferReserve(buffer, count + 1);
		buffer->objects[count++] = objc_retain(obj);
	}

	__builtin_va_end(arguments);

	buffer->count = count;

	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (instancetype)initWithArray:(NSArray *)array
{
	_NSRequireNonnil(array);

	Class const c = object_getClass(array);

	if (c == _NSZeroArrayClass || c == _NSSingleEntryArrayClass || c == _NSInlineArrayClass ||
	    c == _NSSubrangeArrayClass || c == _NSMutableInlineArrayClass)
		return [array mutableCopy];

	NSUInteger const count = array.count;

	_NSForeignArrayRequireCountWithinBounds(array, count);

	NSArrayBuffer *const buffer = NSArrayBufferCreate(count);
	buffer->count = count;

	NSUInteger i = 0;
	for (id __unsafe_unretained obj in array) {
		_NSForeignArrayRequireNonnilObjectAtIndex(array, obj, i);
		buffer->objects[i] = objc_retain(obj);
		++i;
	}

	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (instancetype)initWithArray:(NSArray *)array copyItems:(bool)shouldCopy
{
	_NSRequireNonnil(array);

	if (shouldCopy == false)
		return [array mutableCopy];

	Class const c = object_getClass(array);
	id<NSObject> __unsafe_unretained *objects;
	NSUInteger count;

	if (c == _NSZeroArrayClass)
		return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:NSArrayBufferCreate(0)];
	else if (c == _NSSingleEntryArrayClass) {
		id __unsafe_unretained obj = ((__bridge NSSingleEntryArrayLayout *)array)->anObject;
		NSArrayBuffer *const buffer = NSArrayBufferCreate(1);
		buffer->count = 1;
		buffer->objects[0] = objc_retain([(id<NSCopying>)obj copy]);
		return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:buffer];
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

	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (instancetype)initWithCapacity:(NSUInteger)numberOfItems
{
	if (numberOfItems > NSArrayBufferMaximumCount)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"buffer overflow.");

	return (id)[[NSMutableInlineArray alloc] _initAdoptingBuffer:NSArrayBufferCreate(numberOfItems)];
}

@end

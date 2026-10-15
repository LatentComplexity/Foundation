
#import <FoundationPrivate/NSObject/NSObject.h>
#import <Foundation/NSEnumerator.h>
#import <FoundationPrivate/NSArray/NSarray.h>

/* libobjc2 exports this as a weak symbol. Someday when I have my own runtime, I'll route this through a setter. */
void objc_enumerationMutation(id);

void
objc_enumerationMutation(id anObject)
{
	[NSException raise:NSInternalInconsistencyException
		format:@"collection %@ was mutated while being enumerated.", anObject];
}

@implementation NSEnumerator

- (instancetype)init
{
	_NSClusterRejectUnavailableMethodInvocation(MethodContext);
	return nil;
}

- (NSArray *)allObjects
{
	/* Play it safe and use __strong vars. */
	id firstObject = [self nextObject];
	id secondObject = [self nextObject];

	if (firstObject == nil)
		return [NSArray array];

	if (firstObject != nil && secondObject == nil)
		return [[NSSingleEntryArray alloc] _initWithObject:firstObject];

	id object;
	NSUInteger count = 2;
	NSArrayBuffer *const buffer = NSArrayBufferCreate(4);
	buffer->objects[0] = objc_retain(firstObject);
	buffer->objects[1] = objc_retain(secondObject);

	while ((object = [self nextObject]) != nil) {
		NSArrayBufferReserve(buffer, count + 1);
		buffer->objects[count++] = objc_retain(object);
	}

	buffer->count = count;

	return [[NSInlineArray alloc] _initAdoptingBuffer:buffer];
}

- (nullable id)nextObject
{
	if (object_getClass(self) == [NSEnumerator class])
		_NSRaiseException(MethodContext, NSUninitializedObjectUsageException,
			@"method sent to instance of abstract class.");

	_NSRaiseException(MethodContext, NSUninitializedObjectUsageException,
		@"method must be overridden in subclass.");

	return nil;
}

- (bool)isEqual:(id)anObject
{
	return (uintptr_t)self == (uintptr_t)anObject || object_getClass(anObject) == [NSEnumerator class];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
		objects:(id __unsafe_unretained _Nullable [_Nonnull])stackBuffer
		count:(NSUInteger)stackBufferCapacity
{
	NSUInteger filled = 0;
	id __unsafe_unretained tempObject;

	state->mutationsPtr = &state->extra[0];

	while (filled < stackBufferCapacity && (tempObject = [self nextObject]) != nil)
		stackBuffer[filled++] = tempObject;

	state->itemsPtr = stackBuffer;

	return filled;
}

@end

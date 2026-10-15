
#import <Foundation/NSNull.h>
#import <FoundationPrivate/NSObject/NSObject.h>

@implementation NSNull

static NSUInteger _hash = 0;
static NSNull *_NSNullInstance = nil;
static Class _NSNullClass = Nil;

+ (void)initialize
{
	static NSCallOnceState s = { 0 };

	if (self == [NSNull class])
		NSCallOnce(&s, ^{
			NSRandomBytes(&_hash, sizeof(NSUInteger));
			_NSNullInstance = class_createInstance(self, 0);
			_NSNullClass = [NSNull class];
		});
}

+ (instancetype)alloc
{
	return _NSNullInstance;
}

- (id)copy
{
	return self;
}

+ (instancetype)null
{
	return _NSNullInstance;
}

- (NSUInteger)hash
{
	return _hash;
}

- (bool)isEqual:(id)anObject
{
	/* All instances of NSNull are equal to one another. */
	if ((uintptr_t)self == (uintptr_t)anObject || object_getClass(anObject) == _NSNullClass)
		return true;

	return false;
}

@end


#import <Foundation/NSOrderedCollectionChange.h>
#import <FoundationPrivate/NSObject/NSObject.h>

@implementation NSOrderedCollectionChange

@synthesize object = _object;
@synthesize changeType = _changeType;
@synthesize index = _index;
@synthesize associatedIndex = _associatedIndex;

static unsigned __int128 _NSOrderedCollectionChangeHashKey = 0;
static Class _NSOrderedCollectionChangeClass = Nil;

+ (void)initialize
{
	static NSCallOnceState s = { 0 };

	if (self == [NSOrderedCollectionChange class])
		NSCallOnce(&s, ^{
			NSRandomBytes(&_NSOrderedCollectionChangeHashKey, sizeof(_NSOrderedCollectionChangeHashKey));
			_NSOrderedCollectionChangeClass = [NSOrderedCollectionChange class];
		});
}

+ (instancetype)changeWithObject:(nullable id)anObject type:(NSCollectionChangeType)type
		index:(NSUInteger)index
{
	if ((NSUInteger)type > (NSUInteger)NSCollectionChangeRemove)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"type was invalid.");

	NSOrderedCollectionChange *obj = class_createInstance(_NSOrderedCollectionChangeClass, 0);
	obj->_object = anObject;
	obj->_changeType = type;
	obj->_index = index;
	obj->_associatedIndex = 0;

	return obj;
}

+ (instancetype)changeWithObject:(nullable id)anObject type:(NSCollectionChangeType)type
		index:(NSUInteger)index associatedIndex:(NSUInteger)associatedIndex
{
	if ((NSUInteger)type > (NSUInteger)NSCollectionChangeRemove)
		_NSRaiseException(MethodContext, NSInvalidArgumentException, @"type was invalid.");

	NSOrderedCollectionChange *obj = class_createInstance(_NSOrderedCollectionChangeClass, 0);
	obj->_object = anObject;
	obj->_changeType = type;
	obj->_index = index;
	obj->_associatedIndex = associatedIndex;

	return obj;
}

- (instancetype)init
{
	_NSClusterRejectUnavailableMethodInvocation(MethodContext);
	return nil;
}

- (NSUInteger)hash
{
	return NSSipHash((NSUInteger[]){ ((id<NSObject>)_object).hash, (NSUInteger)_changeType, _index,
		_associatedIndex }, 4 * sizeof(NSUInteger), _NSOrderedCollectionChangeHashKey);
}

- (bool)isEqual:(nullable id)anObject
{
	if ((uintptr_t)self == (uintptr_t)anObject)
		return true;

	if (anObject == nil)
		return false;

	if (object_getClass(anObject) == _NSOrderedCollectionChangeClass) {
		/* Check cheap properties that are more likely to be different first. */
		if (_index == ((NSOrderedCollectionChange *)anObject)->_index &&
		    _associatedIndex == ((NSOrderedCollectionChange *)anObject)->_associatedIndex &&
		    _changeType == ((NSOrderedCollectionChange *)anObject)->_changeType &&
		    [((id<NSObject>)_object) isEqual:((NSOrderedCollectionChange *)anObject)->_object])
			return true;
	}

	return false;
}

@end

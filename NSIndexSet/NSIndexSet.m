
#import <FoundationPrivate/NSIndexSet/NSIndexSet.h>

@implementation NSIndexSet

unsigned __int128 _NSIndexSetHashKey;
NSUInteger _NSZeroIndexSetHash;

Class _NSIndexSetClass;
Class _NSIndexSetTemplateClass;
Class _NSZeroIndexSetClass;
Class _NSSingleEntryIndexSetClass;
Class _NSSingleRangeIndexSetClass;
Class _NSInlineIndexSetClass;
Class _NSMutableIndexSetClass;
Class _NSMutableIndexSetTemplateClass;
Class _NSMutableInlineIndexSetClass;

static NSIndexSetTemplate *_NSIndexSetTemplateInstance = nil;
NSZeroIndexSet *_NSZeroIndexSetInstance = nil;

+ (void)initialize
{
	static NSCallOnceState s = {};

	if (self == [NSIndexSet class] || self == [NSMutableIndexSet class])
		NSCallOnce(&s, ^{
			NSRandomBytes(&_NSIndexSetHashKey, sizeof(_NSIndexSetHashKey));
			_NSZeroIndexSetHash = NSSipHash((NSUInteger[]){ 0, 0 }, sizeof(NSUInteger) * 2,
								_NSIndexSetHashKey);

			_NSIndexSetClass = [NSIndexSet class];
			_NSIndexSetTemplateClass = [NSIndexSetTemplate class];
			_NSZeroIndexSetClass = [NSZeroIndexSet class];
			_NSSingleEntryIndexSetClass = [NSSingleEntryIndexSet class];
			_NSSingleRangeIndexSetClass = [NSSingleRangeIndexSet class];
			_NSInlineIndexSetClass = [NSInlineIndexSet class];
			_NSMutableIndexSetClass = [NSMutableIndexSet class];
			_NSMutableIndexSetTemplateClass = [NSMutableIndexSetTemplate class];
			_NSMutableInlineIndexSetClass = [NSMutableInlineIndexSet class];

			_NSIndexSetTemplateInstance = [NSIndexSetTemplate alloc];
			_NSZeroIndexSetInstance = [NSZeroIndexSet alloc];
		});
}

+ (instancetype)alloc
{
	if (self == _NSIndexSetClass)
		return _NSIndexSetTemplateInstance;

	return class_createInstance(self, 0);
}

- (id)copy
{
	_NSIndexSetRejectInvocation();

	return nil;
}

- (id)mutableCopy
{
	_NSIndexSetRejectInvocation();

	return nil;
}

+ (instancetype)indexSet
{
	return _NSZeroIndexSetInstance;
}

+ (instancetype)indexSetWithIndex:(NSUInteger)index
{
	return [[self alloc] initWithIndex:index];
}

+ (instancetype)indexSetWithIndexesInRange:(NSRange)range
{
	return [[self alloc] initWithIndexesInRange:range];
}

- (instancetype)init
{
	_NSIndexSetRejectReinitialization();
}

- (instancetype)initWithIndexSet:(NSIndexSet *)indexSet
{
	_NSIndexSetRejectReinitialization();
}

- (instancetype)initWithIndex:(NSUInteger)index
{
	_NSIndexSetRejectReinitialization();
}

- (instancetype)initWithIndexesInRange:(NSRange)range
{
	_NSIndexSetRejectReinitialization();
}

- (NSUInteger)count
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)firstIndex
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)lastIndex
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)getIndexes:(NSUInteger *)indexBuffer maxCount:(NSUInteger)bufferSize
		inIndexRange:(nullable NSRange *)rangePointer
{
	_NSIndexSetRejectInvocation();
}

- (bool)containsIndex:(NSUInteger)anIndex
{
	_NSIndexSetRejectInvocation();
}

- (bool)containsIndexes:(NSIndexSet *)indexSet
{
	_NSIndexSetRejectInvocation();
}

- (bool)containsIndexesInRange:(NSRange)range
{
	_NSIndexSetRejectInvocation();
}

- (bool)intersectsIndexesInRange:(NSRange)range
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)indexGreaterThanIndex:(NSUInteger)anIndex
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)indexLessThanIndex:(NSUInteger)anIndex
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)indexGreaterThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)anIndex
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)countOfIndexesInRange:(NSRange)range
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)indexPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)indexWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)indexInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSIndexSetRejectInvocation();
}

- (NSIndexSet *)indexesPassingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSIndexSetRejectInvocation();
}

- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSIndexSetRejectInvocation();
}

- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)options
		passingTest:(bool (NS_NOESCAPE ^)(NSUInteger, bool *))predicate
{
	_NSIndexSetRejectInvocation();
}

/* For the next six methods, we append NS_NORETURN to shut Clang up instead of pragma'ing -Wmissing-noreturn away. */
- (void)enumerateIndexesUsingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block NS_NORETURN
{
	_NSIndexSetRejectInvocation();
}

- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block NS_NORETURN
{
	_NSIndexSetRejectInvocation();
}

- (void)enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSUInteger, bool *))block NS_NORETURN
{
	_NSIndexSetRejectInvocation();
}

- (void)enumerateRangesUsingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block NS_NORETURN
{
	_NSIndexSetRejectInvocation();
}

- (void)enumerateRangesWithOptions:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block NS_NORETURN
{
	_NSIndexSetRejectInvocation();
}

- (void)enumerateRangesInRange:(NSRange)range options:(NSEnumerationOptions)options
	usingBlock:(void (NS_NOESCAPE ^)(NSRange, bool *))block NS_NORETURN
{
	_NSIndexSetRejectInvocation();
}

- (NSUInteger)hash
{
	_NSIndexSetRejectInvocation();
}

- (bool)isEqualToIndexSet:(NSIndexSet *)indexSet
{
	_NSIndexSetRejectInvocation();
}

- (bool)isEqual:(id)anObject
{
	if ((uintptr_t)self == (uintptr_t)anObject)
		return true;

	Class const c = object_getClass(anObject);
	if (c == _NSZeroIndexSetClass || c == _NSSingleEntryIndexSetClass || c == _NSSingleRangeIndexSetClass ||
	    c == _NSInlineIndexSetClass || c == _NSMutableInlineIndexSetClass)
		return [self isEqualToIndexSet:(NSIndexSet *)anObject];

	return false;
}

@end

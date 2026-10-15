
#import <FoundationPrivate/NSData/NSData.h>

@implementation NSData

/*
 * The deallocator is always a Block so that all three deallocator kinds (free(), no-op, custom Block) are stored
 * uniformly in the data buffer.
 */
void (^const NSDataBufferFreeBlock)(void *, NSUInteger) = ^(void *bytes, [[maybe_unused]] NSUInteger count) {
	free(bytes);
};

void (^const NSDataBufferNoFreeBlock)(void *, NSUInteger) =
	^([[maybe_unused]] void *bytes, [[maybe_unused]] NSUInteger count){};

unsigned __int128 _NSDataHashKey;
NSUInteger _NSZeroDataHash;

Class _NSDataClass;
Class _NSDataTemplateClass;
Class _NSZeroDataClass;
Class _NSInlineDataClass;
Class _NSSubrangeDataClass;
Class _NSMutableDataClass;
Class _NSMutableDataTemplateClass;
Class _NSMutableInlineDataClass;

static NSDataTemplate *_NSDataTemplateInstance = nil;
NSZeroData *_NSZeroDataInstance = nil;

+ (void)initialize
{
	static NSCallOnceState s = {};

	if (self == [NSData class] || self == [NSMutableData class])
		NSCallOnce(&s, ^{
			NSRandomBytes(&_NSDataHashKey, sizeof(_NSDataHashKey));
			_NSZeroDataHash = NSSipHash((NSUInteger[]){ 0, 0 }, sizeof(NSUInteger) * 2, _NSDataHashKey);

			_NSDataClass = [NSData class];
			_NSDataTemplateClass = [NSDataTemplate class];
			_NSZeroDataClass = [NSZeroData class];
			_NSInlineDataClass = [NSInlineData class];
			_NSSubrangeDataClass = [NSSubrangeData class];
			_NSMutableDataClass = [NSMutableData class];
			_NSMutableInlineDataClass = [NSMutableInlineData class];

			_NSDataTemplateInstance = [NSDataTemplate alloc];
			_NSZeroDataInstance = [NSZeroData alloc];
		});
}

+ (instancetype)alloc
{
	if (self == _NSDataClass)
		return _NSDataTemplateInstance;

	return class_createInstance(self, 0);
}

- (id)copy
{
	return self;
}

- (id)mutableCopy
{
	return (id)[[NSMutableInlineData alloc] _initWithBytes:self.bytes count:self.count];
}

+ (instancetype)data
{
	return _NSZeroDataInstance;
}

+ (instancetype)dataWithData:(NSData *)data
{
	return [[self alloc] initWithData:data];
}

+ (instancetype)dataWithBytes:(void const *)bytes count:(NSUInteger)count
{
	return [[self alloc] initWithBytes:bytes count:count];
}

+ (instancetype)dataWithBytesNoCopy:(void *)bytes count:(NSUInteger)count
{
	return [[self alloc] initWithBytesNoCopy:bytes count:count];
}

+ (instancetype)dataWithBytesNoCopy:(void *)bytes count:(NSUInteger)count freeWhenDone:(bool)freeBuffer
{
	return [[self alloc] initWithBytesNoCopy:bytes count:count freeWhenDone:freeBuffer];
}

- (instancetype)initWithData:(NSData *)data
{
	_NSDataRejectReinitialization();
}

- (instancetype)initWithBytes:(void const *)bytes count:(NSUInteger)count
{
	_NSDataRejectReinitialization();
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count
{
	_NSDataRejectReinitialization();
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count freeWhenDone:(bool)freeBuffer
{
	_NSDataRejectReinitialization();
}

- (instancetype)initWithBytesNoCopy:(void *)bytes count:(NSUInteger)count
			deallocator:(nullable void (^)(void *, NSUInteger))deallocator
{
	_NSDataRejectReinitialization();
}

- (void const *)bytes
{
	_NSDataRejectInvocation();
}

- (NSUInteger)count
{
	_NSDataRejectInvocation();
}

- (NSData *)subdataWithRange:(NSRange)range
{
	NSUInteger const count = self.count;

	if (range.location == 0 && range.length == count)
		return self;

	_NSRangeWithinUpperBound(range, count);

	if (range.length == 0)
		return _NSZeroDataInstance;

	return [[NSInlineData alloc] _initWithBytes:(char const *)self.bytes + range.location count:range.length];
}

- (void)getBytes:(void *)buffer count:(NSUInteger)count
{
	_NSRequireNonnullptr(buffer);

	memcpy(buffer, self.bytes, MIN(count, self.count));
}

- (void)getBytes:(void *)buffer range:(NSRange)range
{
	_NSRequireNonnullptr(buffer);
	_NSRangeWithinUpperBound(range, self.count);

	/* We have a valid range but effectively requested no data, return. */
	if (range.length == 0)
		return;

	memcpy(buffer, (char const *)self.bytes + range.location, range.length);
}

- (void)enumerateByteRangesUsingBlock:(void (NS_NOESCAPE ^)(void const *, NSRange, bool *))block
{
	_NSRequireNonnil(block);

	block(self.bytes, NSRangeMake(0, self.count), (bool[]){ false });
}

/* TODO: wrap in C routine and place in each subclass. */
- (NSRange)rangeOfData:(NSData *)dataToFind options:(NSDataSearchOptions)searchOptions range:(NSRange)searchRange
{
	_NSRequireNonnil(dataToFind);
	_NSDataSearchOptionsCheck(searchOptions);
	NSUInteger const count = self.count;
	_NSRangeWithinUpperBound(searchRange, count);

	unsigned char const *const bytes = self.bytes;
	NSDataRepresentation const rep = _NSDataGetRepresentation(dataToFind);
	unsigned char const *const needle = rep.bytes;
	NSUInteger const needleLen = rep.count;

	bool const backwards = searchOptions & NSDataSearchBackwards;
	bool const anchored = searchOptions & NSDataSearchAnchored;

	if (needleLen == 0)
		return NSRangeMake(backwards ? NSRangeMax(searchRange) : searchRange.location, 0);

	if (needleLen > searchRange.length)
		return NSRangeMake(NSNotFound, 0);

	/* Inclusive last position a match can start at. */
	NSUInteger const hi = NSRangeMax(searchRange) - needleLen;
	NSUInteger const lo = searchRange.location;

	/* Anchored search is just checking if some bytes lie at the start or end of the range. */
	if (anchored) {
		NSUInteger const offset = backwards ? hi : lo;
		if (memcmp(bytes + offset, needle, needleLen) == 0)
			return NSRangeMake(offset, needleLen);

		return NSRangeMake(NSNotFound, 0);
	}

	/*
	 * Probe each candidate position. The forwards case hands the window off to memmem; the backwards case still
	 * walks candidates with memcmp() until we roll our own two-way search.
	 */
	if (backwards) {
		for (NSUInteger start = hi; ; --start) {
			if (memcmp(bytes + start, needle, needleLen) == 0)
				return NSRangeMake(start, needleLen);
			if (start == lo)
				break;
		}
	} else {
		unsigned char const *const found = memmem(bytes + lo, searchRange.length, needle, needleLen);
		if (found != nullptr)
			return NSRangeMake((NSUInteger)((uintptr_t)found - (uintptr_t)bytes), needleLen);
	}

	return NSRangeMake(NSNotFound, 0);
}

- (NSUInteger)hash
{
	NSUInteger const count = self.count;

	if (count != 0) {
		NSUInteger h;
		NSSipHashContext c;

		NSSipHashContextInit(&c, _NSDataHashKey);
		NSSipHashWithContext(&c, (NSUInteger[]){ count }, sizeof(NSUInteger));
		NSSipHashWithContext(&c, self.bytes, count);
		NSSipHashWithContextFinalize(&c, &h);

		return h;
	} else
		return _NSZeroDataHash;
}

- (bool)isEqualToData:(NSData *)otherData
{
	_NSRequireNonnil(otherData);

	if ((uintptr_t)self == (uintptr_t)otherData)
		return true;

	NSUInteger const count = self.count;
	NSDataRepresentation const rep = _NSDataGetRepresentation(otherData);

	if (count != rep.count)
		return false;

	if (memcmp(self.bytes, rep.bytes, count) == 0)
		return true;

	return false;
}

- (bool)isEqual:(id)anObject
{
	if ((uintptr_t)self == (uintptr_t)anObject)
		return true;

	if ([(id<NSObject>)anObject isKindOfClass:_NSDataClass])
		return [self isEqualToData:(NSData *)anObject];

	return false;
}

@end

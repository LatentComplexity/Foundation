
#import <FoundationPrivate/NSValue/NSValue.h>
#import <FoundationPrivate/NSObject/NSTypeEncodingString.h>

@implementation NSValue

unsigned __int128 _NSValueHashKey;
NSUInteger _NSNullVoidPointerValueHash;

Class _NSValueClass;
Class _NSValueTemplateClass;
Class _NSInlineValueClass;
Class _NSVoidPointerValueClass;
Class _NSNullVoidPointerValueClass;

static NSValueTemplate *_NSValueTemplateInstance = nil;
NSNullVoidPointerValue *_NSNullVoidPointerValueInstance = nil;

+ (void)initialize
{
	static NSCallOnceState s = {};

	if (self == [NSValue class])
		NSCallOnce(&s, ^{
			NSRandomBytes(&_NSValueHashKey, sizeof(_NSValueHashKey));
			_NSValueTemplateInstance = [NSValueTemplate alloc];
			/* "^v" followed by a nullptr. */
			_NSNullVoidPointerValueHash = NSSipHash("^v\0\0\0\0\0\0\0\0", 2 + sizeof(void *),
								_NSValueHashKey);

			_NSValueClass = [NSValue class];
			_NSValueTemplateClass = [NSValueTemplate class];
			_NSInlineValueClass = [NSInlineValue class];
			_NSVoidPointerValueClass = [NSVoidPointerValue class];
			_NSNullVoidPointerValueClass = [NSNullVoidPointerValue class];

			_NSNullVoidPointerValueInstance = [NSNullVoidPointerValue alloc];
		});
}

+ (instancetype)alloc
{
	if (self == _NSValueClass)
		return _NSValueTemplateInstance;

	return class_createInstance(self, 0);
}

- (id)copy
{
	return self;
}

+ (instancetype)valueWithBytes:(void const *)value objCType:(char const *)type
{
	return [[self alloc] initWithBytes:value objCType:type];
}

+ (instancetype)valueWithPointer:(nullable void const *)pointer
{
	return pointer ? (id)[NSVoidPointerValue _valueWithPointer:(void const *_Nonnull)pointer] :
			(id)_NSNullVoidPointerValueInstance;
}

- (instancetype)initWithBytes:(void const *)value objCType:(char const *)type
{
	_NSValueRejectReinitialization();
}

- (char const *)objCType
{
	_NSValueRejectInvocation();
}

- (nullable void *)pointerValue
{
	char const *type = self.objCType;
	void *ptr;

	/* TODO: *sigh*. */
	if (NSTypeEncodingStringSizeOf(type) == sizeof(void *)) {
		[self getValue:&ptr size:sizeof(void *)];
		return ptr;
	}

	return nullptr;
}

- (void)getValue:(void *)value size:(NSUInteger)size NS_NORETURN
{
	_NSValueRejectInvocation();
}

- (NSUInteger)hash
{
	NSSipHashContext c = {};
	NSUInteger h;

	char const *const type = self.objCType;
	NSUInteger const size = NSTypeEncodingStringSizeOf(type);
	void *const data = _NSMalloc(size);
	[self getValue:data size:size];

	NSSipHashContextInit(&c, _NSValueHashKey);
	NSSipHashWithContext(&c, type, strlen(type));
	NSSipHashWithContext(&c, data, size);
	NSSipHashWithContextFinalize(&c, &h);

	free(data);

	return h;
}

- (bool)isEqualToValue:(NSValue *)aValue
{
	_NSRequireNonnil(aValue);

	if ((uintptr_t)self == (uintptr_t)aValue)
		return true;

	if (strcmp(self.objCType, aValue.objCType) != 0)
		return false;

	NSUInteger const size = NSTypeEncodingStringSizeOf(self.objCType);

	void *const data = _NSMalloc(size);
	void *const otherData = _NSMalloc(size);

	[self getValue:data size:size];
	[aValue getValue:otherData size:size];

	bool const result = memcmp(data, otherData, size) == 0;

	free(data);
	free(otherData);

	return result;
}

- (bool)isEqual:(id)anObject
{
	if ((uintptr_t)self == (uintptr_t)anObject)
		return true;

	if ([(id<NSObject>)anObject isKindOfClass:_NSValueClass])
		return [self isEqualToValue:(NSValue *)anObject];

	return false;
}

@end

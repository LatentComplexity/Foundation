
#import <Foundation/NSUUID.h>
#import <FoundationPrivate/NSObject/NSObject.h>

enum UUIDRepresentationInfo : unsigned char {
	UUIDCharactersLength = 36
};

enum UUIDVersionInfo : unsigned char {
	UUIDVersionMask = 0xF,
	UUIDVersionShift = 76,
	UUIDVersion = 4
};

enum UUIDVariantInfo : unsigned char {
	UUIDVariantMask = 3,
	UUIDVariantShift = 62,
	UUIDVariant = 0b10
};

@implementation NSUUID {
	UUID_t _UUIDBytes;
}

static unsigned __int128 _NSUUIDHashKey = 0;
static Class _NSUUIDClass = Nil;

+ (void)initialize
{
	static NSCallOnceState s = { 0 };

	if (self == [NSUUID class])
		NSCallOnce(&s, ^{
			NSRandomBytes(&_NSUUIDHashKey, sizeof(_NSUUIDHashKey));
			_NSUUIDClass = [NSUUID class];
		});
}

- (id)copy
{
	return self;
}

+ (instancetype)UUID
{
	UUID_t bytes;

	/* Fill with random bytes, then clear the version and variant fields and place appropriate values in them. */
	NSRandomBytes(&bytes, sizeof(UUID_t));
	bytes &= ~((UUID_t)UUIDVersionMask << UUIDVersionShift) & ~((UUID_t)UUIDVariantMask << UUIDVariantShift);
	bytes |= (UUID_t)UUIDVersion << UUIDVersionShift | (UUID_t)UUIDVariant << UUIDVariantShift;

	NSUUID *obj = class_createInstance(_NSUUIDClass, 0);
	obj->_UUIDBytes = bytes;

	return obj;
}

+ (nullable instancetype)UUIDWithUUIDString:(NSString *)string
{
	_NSRequireNonnil(string);

	UUID_t bytes = 0;
	unichar UUIDCharacters[UUIDCharactersLength];

	if (string.length != UUIDCharactersLength)
		return nil;

	[string getCharacters:UUIDCharacters range:NSRangeMake(0, UUIDCharactersLength)];

	/* The canonical representation has four hyphens at fixed positions. */
	if (UUIDCharacters[8] != '-' || UUIDCharacters[13] != '-' || UUIDCharacters[18] != '-' ||
	    UUIDCharacters[23] != '-')
		return nil;

	/* Parse exactly 32 hexadecimal digits. Version and variant bits are deliberately opaque here. */
	for (unsigned char i = 0; i < UUIDCharactersLength; ++i) {
		unichar const character = UUIDCharacters[i];
		unsigned char digit;

		if (i == 8 || i == 13 || i == 18 || i == 23)
			continue;

		if (character >= '0' && character <= '9')
			digit = (unsigned char)(character - '0');
		else if (character >= 'A' && character <= 'F')
			digit = (unsigned char)(character - 'A' + 10);
		else if (character >= 'a' && character <= 'f')
			digit = (unsigned char)(character - 'a' + 10);
		else
			return nil;

		bytes = (bytes << 4) | (UUID_t)digit;
	}

	NSUUID *obj = class_createInstance(_NSUUIDClass, 0);
	obj->_UUIDBytes = bytes;

	return obj;
}

+ (instancetype)UUIDWithUUIDBytes:(UUID_t const)bytes
{
	NSUUID *obj = class_createInstance(_NSUUIDClass, 0);
	obj->_UUIDBytes = bytes;

	return obj;
}

- (instancetype)init
{
	_NSClusterRejectUnavailableMethodInvocation(MethodContext);
	return nil;
}

- (NSString *)UUIDString
{
	char UUIDString[UUIDCharactersLength];

	for (unsigned char i = 0, octet = 0; i < UUIDCharactersLength; ++i) {
		if (i == 8 || i == 13 || i == 18 || i == 23) {
			UUIDString[i] = '-';
			continue;
		}

		unsigned char const octetVal = (_UUIDBytes >> (124 - (4 * octet++))) & 0xF;

		if (octetVal <= 9)
			UUIDString[i] = octetVal + '0';		/* 0 to 9. */
		else
			UUIDString[i] = octetVal + 'A' - 10;	/* 10 to 15. */
	}

	return (NSString *_Nonnull)[[NSString alloc] initWithBytes:UUIDString length:UUIDCharactersLength
		encoding:NSASCIIStringEncoding];
}

- (void)getUUIDBytes:(nonnull UUID_t *)uuidBytes
{
	_NSRequireNonnullptr(uuidBytes);

	*uuidBytes = _UUIDBytes;
}

- (NSUInteger)hash
{
	return NSSipHash(&_UUIDBytes, sizeof(UUID_t), _NSUUIDHashKey);
}

- (NSString *)description
{
	return [self UUIDString];
}

- (bool)isEqualToUUID:(NSUUID *)otherUUID
{
	_NSRequireNonnil(otherUUID);

	if ((uintptr_t)self == (uintptr_t)otherUUID)
		return true;

	return _UUIDBytes == otherUUID->_UUIDBytes;
}

- (bool)isEqual:(id)anObject
{
	if ((uintptr_t)self == (uintptr_t)anObject)
		return true;

	if (anObject == nil)
		return false;

	if (object_getClass(anObject) == _NSUUIDClass)
		return [self isEqualToUUID:(NSUUID *)anObject];

	return false;
}

- (NSComparisonResult)compare:(NSUUID *)otherUUID
{
	_NSRequireNonnil(otherUUID);

	return (NSComparisonResult)((_UUIDBytes > otherUUID->_UUIDBytes) - (_UUIDBytes < otherUUID->_UUIDBytes));
}

@end

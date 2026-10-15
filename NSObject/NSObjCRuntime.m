
#import <FoundationPrivate/NSObject/NSObject.h>
#import <FoundationPrivate/NSString/NSStringBuilder.h>
#import <FoundationPrivate/NSObject/NSTypeEncodingString.h>

NSString *
NSStringFromClass(Class c)
{
	return (NSString *_Nonnull)@(class_getName(c));
}

Class
NSClassFromString(NSString *aString)
{
	return objc_getClass(aString.UTF8String);
}

NSString *
NSStringFromSelector(SEL aSel)
{
	return (NSString *_Nonnull)@(sel_getName(aSel));
}

SEL
NSSelectorFromString(NSString *aString)
{
	return sel_registerName(aString.UTF8String);
}

NSString *
NSStringFromProtocol(Protocol *aProtocol)
{
	return (NSString *_Nonnull)@(protocol_getName(aProtocol));
}

Protocol *
NSProtocolFromString(NSString *aString)
{
	return objc_getProtocol(aString.UTF8String);
}

char const *
NSGetSizeAndAlignment(char const *type, NSUInteger *size, NSUInteger *alignment)
{
	NSTypeEncodingStringResult r = NSTypeEncodingStringValidate(NSTypeEncodingStringSchemeStorable, type);
	char const *next;

	if (r.status != NSTypeEncodingStringStatusOK)
		[NSException raise:NSInvalidArgumentException format:@"%s: %@", __PRETTY_FUNCTION__, r.reason];

	/* Measure the one type, then step over any trailing frame offset so the result points at the next type. */
	/* TODO: parse the number as a whole and throw if it is non-sensical like in NSTypeEncodingStringValidate(). */
	next = NSTypeEncodingStringMeasure(type, size, alignment, nullptr);
	while (*next >= '0' && *next <= '9')
		++next;

	return next;
}

/*
 * Each NSLog() call writes its full message to stderr in one write(); the lock ensures interleaved calls don't
 * corrupt each other's output.
 */
static NSMutex _NSLogMutex = {};

void
NSLogv(NSString *format, __builtin_va_list ap)
{
	if (format == nil)
		[NSException raise:NSInvalidArgumentException format:@"%s: format was nil.", __PRETTY_FUNCTION__];

	NSStringBuilderResult const r = NSStringBuilder(NSStringBuilderEncodingUTF8, format, ap);
	char *outBytes = r.data.utf8;
	NSUInteger n = r.length;

	/* NSLog terminates each message with a newline. Append one unless the format already produced one. */
	if (n == 0 || outBytes[n - 1] != '\n') {
		char *grown = realloc(outBytes, n + 1);

		if (grown == nullptr)
			abort();

		outBytes = grown;
		outBytes[n++] = '\n';
	}

	NSMutexLock(&_NSLogMutex);

	NSUInteger off = 0;
	while (off < n) {
		long const w = write(2, outBytes + off, n - off);

		if (w <= 0)
			break;

		if (__builtin_add_overflow(off, (NSUInteger)w, &off))
			[NSException raise:NSInvalidArgumentException
				format:@"%s: how much text can one human possibly log?", __PRETTY_FUNCTION__];
	}

	NSMutexUnlock(&_NSLogMutex);

	free(outBytes);
}

void
NSLog(NSString *format, ...)
{
	__builtin_va_list arguments;

	__builtin_va_start(arguments, format);
	NSLogv(format, arguments);
	__builtin_va_end(arguments);
}

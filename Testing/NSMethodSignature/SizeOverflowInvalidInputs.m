#import <Foundation/NSException.h>
#import <Foundation/NSMethodSignature.h>
#import "Test.h"

#include <errno.h>
#include <sys/wait.h>
#include <unistd.h>

/* A malformed-size input must raise the public exception, rather than trapping in the trusted measurement pass.
 * Separate children let every regression run even while the old implementation still traps or aborts under UBSan. */
static void
TestRejectedSize(char const *encoding)
{
	pid_t child = fork();
	TEST(child >= 0);
	if (child < 0) return;
	if (child == 0) {
		@autoreleasepool {
			@try {
				(void)[NSMethodSignature signatureWithObjCTypes:encoding];
			} @catch (NSException *exception) {
				TestChildExit([exception.name isEqual:NSInvalidArgumentException] ? 0 : 3);
			}
		}
		TestChildExit(2); /* Unexpectedly accepted. */
	}
	int status = 0;
	pid_t waited;
	do { waited = waitpid(child, &status, 0); } while (waited < 0 && errno == EINTR);
	TEST(waited == child);
	if (waited == child)
		TESTF(WIFEXITED(status) && WEXITSTATUS(status) == 0, "size validation failed for %s (wait status=%d)",
			encoding, status);
}

int
main(void)
{
	char const *const encodings[] = {
		"v@:{Huge=[2305843009213693952Q]}",
		"{Huge=[2305843009213693952Q]}@:",
		"v@:{Nested=[2{Huge=[1152921504606846976Q]}]}",
		"v@:{Sum=[2305843009213693951Q]Q}",
		/* Each field fits the internal bit count, but their sum does not. */
		"v@:{Sum=[1152921504606846975C][1152921504606846975C]qq}",
		/* Rounding to the final eight-byte structure alignment itself overflows. */
		"v@:{Round=q[2305843009213693943C]}",
		/* Rounding before the next field overflows, even when that field occupies no bytes. */
		"v@:{Round=[2305843009213693951C][0q]}",
		/* Zero-sized leaves still have a representable-count requirement. */
		"v@:{Leaves=[18446744073709551615v]v}",
		"v@:{Leaves=[2[18446744073709551615v]]}",
		/* A pointer does not hide an unrepresentable nested type from validation. */
		"v@:^{Huge=[2305843009213693952Q]}",
		/* Eight individually representable, promoted arguments overflow the combined frame length. */
		"v@:{A=[2305843009213693951C]}{A=[2305843009213693951C]}"
		"{A=[2305843009213693951C]}{A=[2305843009213693951C]}"
		"{A=[2305843009213693951C]}{A=[2305843009213693951C]}"
		"{A=[2305843009213693951C]}{A=[2305843009213693951C]}",
		/* One pointer-width beyond the maximum frame accepted by Construction.m. */
		"v@:{A=[2305843009213693951C]}{A=[2305843009213693951C]}"
		"{A=[2305843009213693951C]}{A=[2305843009213693951C]}"
		"{A=[2305843009213693951C]}{A=[2305843009213693951C]}"
		"{A=[2305843009213693951C]}{Last=[2305843009213693936C]}",
		/* A count too large even to parse remains the ordinary malformed-input control. */
		"v@:{Huge=[184467440737095516160Q]}"
	};
	for (NSUInteger i = 0; i < sizeof(encodings) / sizeof(encodings[0]); ++i)
		TestRejectedSize(encodings[i]);
	return TestFinish();
}

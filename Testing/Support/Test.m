#import "Test.h"

#include <math.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if __has_feature(address_sanitizer)
#include <sanitizer/lsan_interface.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

static _Atomic unsigned TestCount;
static _Atomic unsigned FailureCount;

[[noreturn]] void
TestChildExit(int status)
{
#if defined(FOUNDATION_TEST_COVERAGE)
	exit(status);
#else
	_Exit(status);
#endif
}

static char const *
TestLeafName(char const *path)
{
	char const *leaf;

	leaf = strrchr(path, '/');
	return leaf != nullptr ? leaf + 1 : path;
}

static void
TestIncrement(bool passed)
{
	atomic_fetch_add_explicit(&TestCount, 1, memory_order_relaxed);
	if (passed == false)
		atomic_fetch_add_explicit(&FailureCount, 1, memory_order_relaxed);
}

void
TestRecord(bool passed, char const *file, unsigned line, char const *function, char const *expression,
	char const *message)
{
	TestIncrement(passed);
	if (passed)
		return;

	if (message != nullptr)
		fprintf(stderr, "%s:%u: FAIL in %s: %s -- %s\n", TestLeafName(file), line, function, expression, message);
	else
		fprintf(stderr, "%s:%u: FAIL in %s: %s\n", TestLeafName(file), line, function, expression);
}

void
TestRecordFormat(bool passed, char const *file, unsigned line, char const *function, char const *expression,
	char const *format, ...)
{
	va_list arguments;

	TestIncrement(passed);
	if (passed)
		return;

	fprintf(stderr, "%s:%u: FAIL in %s: %s -- ", TestLeafName(file), line, function, expression);
	va_start(arguments, format);
	vfprintf(stderr, format, arguments);
	va_end(arguments);
	fputc('\n', stderr);
}

void
TestRecordSignedEquality(intmax_t actual, intmax_t expected, char const *file, unsigned line,
	char const *function, char const *actualExpression, char const *expectedExpression)
{
	bool const passed = actual == expected;

	TestIncrement(passed);
	if (passed == false)
		fprintf(stderr, "%s:%u: FAIL in %s: %s = %jd, expected %s = %jd\n", TestLeafName(file), line,
			function, actualExpression, actual, expectedExpression, expected);
}

void
TestRecordUnsignedEquality(uintmax_t actual, uintmax_t expected, char const *file, unsigned line,
	char const *function, char const *actualExpression, char const *expectedExpression)
{
	bool const passed = actual == expected;

	TestIncrement(passed);
	if (passed == false)
		fprintf(stderr, "%s:%u: FAIL in %s: %s = %ju, expected %s = %ju\n", TestLeafName(file), line,
			function, actualExpression, actual, expectedExpression, expected);
}

void
TestRecordDoubleNear(double actual, double expected, double tolerance, char const *file, unsigned line,
	char const *function, char const *actualExpression, char const *expectedExpression)
{
	bool const passed = fabs(actual - expected) <= tolerance;

	TestIncrement(passed);
	if (passed == false)
		fprintf(stderr, "%s:%u: FAIL in %s: %s = %.17g, expected %s = %.17g within %.17g\n",
			TestLeafName(file), line, function, actualExpression, actual, expectedExpression, expected, tolerance);
}

void
TestRecordStringEquality(char const *actual, char const *expected, char const *file, unsigned line,
	char const *function, char const *actualExpression, char const *expectedExpression, char const *message)
{
	bool const passed = actual == expected ||
		(actual != nullptr && expected != nullptr && strcmp(actual, expected) == 0);

	TestIncrement(passed);
	if (passed)
		return;

	fprintf(stderr, "%s:%u: FAIL in %s: %s = %s\n    expected %s = %s", TestLeafName(file), line,
		function, actualExpression, actual != nullptr ? actual : "(null)", expectedExpression,
		expected != nullptr ? expected : "(null)");
	if (message != nullptr)
		fprintf(stderr, " -- %s", message);
	fputc('\n', stderr);
}

void
TestRecordBytesEquality(void const *actual, void const *expected, size_t length, char const *file, unsigned line,
	char const *function, char const *actualExpression, char const *expectedExpression)
{
	size_t mismatch = 0;
	bool passed;

	passed = actual == expected || length == 0 ||
		(actual != nullptr && expected != nullptr && memcmp(actual, expected, length) == 0);
	TestIncrement(passed);
	if (passed)
		return;

	if (actual == nullptr || expected == nullptr) {
		fprintf(stderr, "%s:%u: FAIL in %s: %s and %s differ over %zu bytes (one pointer is null)\n",
			TestLeafName(file), line, function, actualExpression, expectedExpression, length);
		return;
	}

	while (mismatch < length && ((unsigned char const *)actual)[mismatch] ==
		((unsigned char const *)expected)[mismatch])
		++mismatch;

	fprintf(stderr, "%s:%u: FAIL in %s: %s and %s first differ at byte %zu: 0x%02x != 0x%02x\n",
		TestLeafName(file), line, function, actualExpression, expectedExpression, mismatch,
		((unsigned char const *)actual)[mismatch], ((unsigned char const *)expected)[mismatch]);
}

void
TestRecordObjectEquality(id actual, id expected, bool shouldEqual, char const *file, unsigned line,
	char const *function, char const *actualExpression, char const *expectedExpression)
{
	bool equal;
	bool passed;

	equal = actual == expected || [(NSObject *)actual isEqual:expected];
	passed = equal == shouldEqual;
	TestIncrement(passed);
	if (passed == false)
		fprintf(stderr, "%s:%u: FAIL in %s: %s is %sequal to %s\n", TestLeafName(file), line, function,
			actualExpression, shouldEqual ? "not " : "", expectedExpression);
}

void
TestRecordException(NSException *exception, NSString *expectedName, NSString *expectedReason, char const *file,
	unsigned line, char const *function, char const *expression)
{
	char const *actualName;
	char const *actualReason;
	bool passed;

	passed = exception != nil;
	if (passed && expectedName != nil)
		passed = [exception.name isEqual:expectedName];
	if (passed && expectedReason != nil)
		passed = [exception.reason isEqual:expectedReason];

	TestIncrement(passed);
	if (passed)
		return;

	if (exception == nil) {
		fprintf(stderr, "%s:%u: FAIL in %s: %s did not throw\n", TestLeafName(file), line, function, expression);
		return;
	}

	actualName = exception.name != nil ? exception.name.UTF8String : "(nil)";
	actualReason = exception.reason != nil ? exception.reason.UTF8String : "no reason";
	fprintf(stderr, "%s:%u: FAIL in %s: %s threw %s (%s)", TestLeafName(file), line, function, expression,
		actualName, actualReason);
	if (expectedName != nil)
		fprintf(stderr, ", expected %s", expectedName.UTF8String);
	if (expectedReason != nil)
		fprintf(stderr, " (%s)", expectedReason.UTF8String);
	fputc('\n', stderr);
}

#if __has_feature(address_sanitizer)
void
TestRecordExpectedExceptionChild(long childValue, char const *file, unsigned line, char const *function,
	char const *expression)
{
	pid_t const child = (pid_t)childValue;

	if (child < 0) {
		TestRecord(false, file, line, function, expression, "fork failed");
		return;
	}

	int status = 0;
	pid_t waited;

	do
		waited = waitpid(child, &status, 0);
	while (waited < 0 && errno == EINTR);
	bool const passed = waited == child && WIFEXITED(status) && WEXITSTATUS(status) == EXIT_SUCCESS;

	TestIncrement(passed);
	if (passed)
		return;
	if (waited != child)
		fprintf(stderr, "%s:%u: FAIL in %s: %s -- waitpid failed\n", TestLeafName(file), line, function,
			expression);
	else if (WIFSIGNALED(status))
		fprintf(stderr, "%s:%u: FAIL in %s: %s -- child terminated by signal %d\n", TestLeafName(file), line,
			function, expression, WTERMSIG(status));
	else if (WIFEXITED(status) == false || WEXITSTATUS(status) != EXIT_FAILURE)
		fprintf(stderr, "%s:%u: FAIL in %s: %s -- child exited abnormally\n", TestLeafName(file), line,
			function, expression);
}
#endif

void
TestExpectedLeaksBegin(void)
{
#if __has_feature(address_sanitizer)
	/* ARC deliberately omits exception-path cleanup; ignore only allocations made by an expected throw. */
	__lsan_disable();
#endif
}

void
TestExpectedLeaksEnd(void)
{
#if __has_feature(address_sanitizer)
	__lsan_enable();
#endif
}

int
TestFinish(void)
{
	unsigned const tests = atomic_load_explicit(&TestCount, memory_order_relaxed);
	unsigned const failures = atomic_load_explicit(&FailureCount, memory_order_relaxed);

	if (failures == 0) {
		printf("OK (%u assertion%s)\n", tests, tests == 1 ? "" : "s");
		return EXIT_SUCCESS;
	}

	fprintf(stderr, "FAILED (%u of %u assertions failed)\n", failures, tests);
	return EXIT_FAILURE;
}

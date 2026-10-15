#ifndef FOUNDATION_TEST_H
#define FOUNDATION_TEST_H

#import <Foundation/NSException.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#include <inttypes.h>
#include <stddef.h>

#if __has_feature(address_sanitizer)
#include <sys/types.h>
#include <unistd.h>
#endif

NS_ASSUME_NONNULL_BEGIN

void
TestRecord(bool passed, char const *file, unsigned line, char const *function, char const *expression,
	char const *_Nullable message);

void
TestRecordFormat(bool passed, char const *file, unsigned line, char const *function, char const *expression,
	char const *format, ...) __attribute__((format(printf, 6, 7)));

void
TestRecordSignedEquality(intmax_t actual, intmax_t expected, char const *file, unsigned line,
	char const *function, char const *actualExpression, char const *expectedExpression);

void
TestRecordUnsignedEquality(uintmax_t actual, uintmax_t expected, char const *file, unsigned line,
	char const *function, char const *actualExpression, char const *expectedExpression);

void
TestRecordDoubleNear(double actual, double expected, double tolerance, char const *file, unsigned line,
	char const *function, char const *actualExpression, char const *expectedExpression);

void
TestRecordStringEquality(char const *_Nullable actual, char const *_Nullable expected, char const *file,
	unsigned line, char const *function, char const *actualExpression, char const *expectedExpression,
	char const *_Nullable message);

void
TestRecordBytesEquality(void const *_Nullable actual, void const *_Nullable expected, size_t length,
	char const *file, unsigned line, char const *function, char const *actualExpression,
	char const *expectedExpression);

void
TestRecordObjectEquality(id _Nullable actual, id _Nullable expected, bool shouldEqual, char const *file,
	unsigned line, char const *function, char const *actualExpression, char const *expectedExpression);

void
TestRecordException(NSException *_Nullable exception, NSString *_Nullable expectedName,
	NSString *_Nullable expectedReason, char const *file, unsigned line, char const *function,
	char const *expression);

#if __has_feature(address_sanitizer)
void
TestRecordExpectedExceptionChild(long child, char const *file, unsigned line, char const *function,
	char const *expression);
#endif

void
TestExpectedLeaksBegin(void);

void
TestExpectedLeaksEnd(void);

int
TestFinish(void);

/* Controlled child termination: coverage builds run the profile writers registered with atexit(). */
[[noreturn]] void
TestChildExit(int status);

#define TEST(...) \
	TestRecord((bool)(__VA_ARGS__), __FILE__, __LINE__, __func__, #__VA_ARGS__, nullptr)

#define TEST_MSG(condition, message) \
	TestRecord((bool)(condition), __FILE__, __LINE__, __func__, #condition, (message))

#define TESTF(condition, format, ...) \
	TestRecordFormat((bool)(condition), __FILE__, __LINE__, __func__, #condition, (format) __VA_OPT__(,) __VA_ARGS__)

#define TEST_EQ(actualExpression, expectedExpression) \
	do { \
		typeof_unqual(actualExpression) const _testActual = (actualExpression); \
		typeof_unqual(expectedExpression) const _testExpected = (expectedExpression); \
		TestRecord((bool)(_testActual == _testExpected), __FILE__, __LINE__, __func__, \
			#actualExpression " == " #expectedExpression, nullptr); \
	} while (0)

#define TEST_NE(actualExpression, expectedExpression) \
	do { \
		typeof_unqual(actualExpression) const _testActual = (actualExpression); \
		typeof_unqual(expectedExpression) const _testExpected = (expectedExpression); \
		TestRecord((bool)(_testActual != _testExpected), __FILE__, __LINE__, __func__, \
			#actualExpression " != " #expectedExpression, nullptr); \
	} while (0)

#define TEST_EQ_SIGNED(actualExpression, expectedExpression) \
	TestRecordSignedEquality((intmax_t)(actualExpression), (intmax_t)(expectedExpression), __FILE__, __LINE__, \
		__func__, #actualExpression, #expectedExpression)

#define TEST_EQ_UNSIGNED(actualExpression, expectedExpression) \
	TestRecordUnsignedEquality((uintmax_t)(actualExpression), (uintmax_t)(expectedExpression), __FILE__, __LINE__, \
		__func__, #actualExpression, #expectedExpression)

#define TEST_NEAR(actualExpression, expectedExpression, toleranceExpression) \
	TestRecordDoubleNear((double)(actualExpression), (double)(expectedExpression), (double)(toleranceExpression), \
		__FILE__, __LINE__, __func__, #actualExpression, #expectedExpression)

#define TEST_OBJ_EQ(actualExpression, expectedExpression) \
	TestRecordObjectEquality((actualExpression), (expectedExpression), true, __FILE__, __LINE__, __func__, \
		#actualExpression, #expectedExpression)

#define TEST_OBJ_NE(actualExpression, expectedExpression) \
	TestRecordObjectEquality((actualExpression), (expectedExpression), false, __FILE__, __LINE__, __func__, \
		#actualExpression, #expectedExpression)

#define TEST_STR_EQ(actualExpression, expectedExpression) \
	TestRecordStringEquality((actualExpression), (expectedExpression), __FILE__, __LINE__, __func__, \
		#actualExpression, #expectedExpression, nullptr)

#define TEST_STR_EQ_MSG(actualExpression, expectedExpression, message) \
	TestRecordStringEquality((actualExpression), (expectedExpression), __FILE__, __LINE__, __func__, \
		#actualExpression, #expectedExpression, (message))

#define TEST_BYTES_EQ(actualExpression, expectedExpression, lengthExpression) \
	TestRecordBytesEquality((actualExpression), (expectedExpression), (size_t)(lengthExpression), __FILE__, __LINE__, \
		__func__, #actualExpression, #expectedExpression)

#if __has_feature(address_sanitizer)
#define _TEST_EXPECTS_EXCEPTION(expectedName, expectedReason, expression, ...) \
	do { \
		NSString *_Nullable const _testExpectedName = (expectedName); \
		NSString *_Nullable const _testExpectedReason = (expectedReason); \
		pid_t const _testChild = fork(); \
		if (_testChild == 0) { \
			NSException *_Nullable _testException = nil; \
			bool _testPassed; \
			@autoreleasepool { \
				@try { \
					__VA_ARGS__; \
				} @catch (NSException *_caughtException) { \
					_testException = _caughtException; \
				} \
				TestRecordException(_testException, _testExpectedName, _testExpectedReason, __FILE__, __LINE__, \
					__func__, (expression)); \
				_testPassed = _testException != nil && \
					(_testExpectedName == nil || [_testException.name isEqual:_testExpectedName]) && \
					(_testExpectedReason == nil || [_testException.reason isEqual:_testExpectedReason]); \
			} \
			_exit(_testPassed ? 0 : 1); \
		} \
		TestRecordExpectedExceptionChild((long)_testChild, __FILE__, __LINE__, __func__, (expression)); \
	} while (0)
#else
#define _TEST_EXPECTS_EXCEPTION(expectedName, expectedReason, expression, ...) \
	do { \
		NSException *_Nullable _testException = nil; \
		NSString *_Nullable const _testExpectedName = (expectedName); \
		NSString *_Nullable const _testExpectedReason = (expectedReason); \
		@try { \
			__VA_ARGS__; \
		} @catch (NSException *_caughtException) { \
			_testException = _caughtException; \
		} \
		TestRecordException(_testException, _testExpectedName, _testExpectedReason, __FILE__, __LINE__, __func__, \
			(expression)); \
	} while (0)
#endif

#define TEST_THROWS(...) \
	_TEST_EXPECTS_EXCEPTION(nil, nil, #__VA_ARGS__, __VA_ARGS__)

#define TEST_THROWS_NAME(expectedName, ...) \
	_TEST_EXPECTS_EXCEPTION((expectedName), nil, #__VA_ARGS__, __VA_ARGS__)

#define TEST_THROWS_MATCHING(expectedName, expectedReason, ...) \
	_TEST_EXPECTS_EXCEPTION((expectedName), (expectedReason), #__VA_ARGS__, __VA_ARGS__)

#define TEST_NO_THROW(...) \
	do { \
		NSException *_Nullable _testException = nil; \
		@try { \
			__VA_ARGS__; \
		} @catch (NSException *_caughtException) { \
			_testException = _caughtException; \
		} \
		TestRecord(_testException == nil, __FILE__, __LINE__, __func__, #__VA_ARGS__ " does not throw", \
			_testException != nil ? _testException.name.UTF8String : nullptr); \
	} while (0)

NS_ASSUME_NONNULL_END

#endif

#import <Foundation/NSException.h>
#import "Test.h"

#include <pthread.h>
#include <sched.h>
#include <stdatomic.h>
#include <string.h>

enum {
	ThreadCount = 8,
	ThrowsPerThread = 1000
};

typedef struct ThreadTestState {
	_Atomic unsigned ready;
	_Atomic unsigned failures;
	_Atomic unsigned start;
} ThreadTestState;

typedef struct ThreadArguments {
	ThreadTestState *state;
	NSUInteger index;
} ThreadArguments;

typedef void *(*ThreadRoutine)(void *);

static void
WaitForStart(ThreadTestState *state)
{
	atomic_fetch_add_explicit(&state->ready, 1, memory_order_release);
	while (atomic_load_explicit(&state->start, memory_order_acquire) == 0)
		sched_yield();
}

static void
RecordThreadFailure(ThreadTestState *state)
{
	atomic_fetch_add_explicit(&state->failures, 1, memory_order_relaxed);
}

static void *
ThrowExistingException(void *context)
{
	ThreadArguments *arguments = context;
	ThreadTestState *state = arguments->state;

	@autoreleasepool {
		NSString *name = [NSString stringWithFormat:@"ExistingException-%lu", arguments->index];
		NSString *reason = [NSString stringWithFormat:@"thread %lu", arguments->index];
		NSObject *userInfo = [NSObject new];
		NSException *exception = [NSException exceptionWithName:name reason:reason userInfo:userInfo];

		WaitForStart(state);

		for (unsigned i = 0; i < ThrowsPerThread; ++i) {
			NSException *caught = nil;

			TestExpectedLeaksBegin();
			@try {
				@throw exception;
			} @catch (NSException *candidate) {
				caught = candidate;
			}
			TestExpectedLeaksEnd();

			if (caught != exception || caught.userInfo != userInfo ||
				[caught.name isEqual:name] == false || [caught.reason isEqual:reason] == false)
				RecordThreadFailure(state);
		}
	}

	return nullptr;
}

static void *
RaiseNewExceptions(void *context)
{
	ThreadArguments *arguments = context;
	ThreadTestState *state = arguments->state;

	@autoreleasepool {
		NSString *name = [NSString stringWithFormat:@"FormattedException-%lu", arguments->index];

		WaitForStart(state);

		for (unsigned i = 0; i < ThrowsPerThread; ++i) {
			@autoreleasepool {
				NSException *caught = nil;
				NSString *expectedReason = [NSString stringWithFormat:@"thread %lu iteration %u",
					arguments->index, i];

				TestExpectedLeaksBegin();
				@try {
					[NSException raise:name format:@"thread %lu iteration %u", arguments->index, i];
				} @catch (NSException *candidate) {
					caught = candidate;
				}
				TestExpectedLeaksEnd();

				if (caught == nil || [caught.name isEqual:name] == false ||
					strcmp(caught.reason.UTF8String, expectedReason.UTF8String) != 0 ||
					caught.userInfo != nil)
					RecordThreadFailure(state);
			}
		}
	}

	return nullptr;
}

static void
RunThreadTest(ThreadRoutine routine)
{
	ThreadTestState state = {};
	pthread_t threads[ThreadCount];
	ThreadArguments arguments[ThreadCount];
	unsigned created = 0;

	for (unsigned i = 0; i < ThreadCount; ++i) {
		int error;

		arguments[created].state = &state;
		arguments[created].index = i;
		error = pthread_create(&threads[created], nullptr, routine, &arguments[created]);
		TEST_EQ_SIGNED(error, 0);
		if (error == 0)
			++created;
	}

	while (atomic_load_explicit(&state.ready, memory_order_acquire) != created)
		sched_yield();
	atomic_store_explicit(&state.start, 1, memory_order_release);

	for (unsigned i = 0; i < created; ++i)
		TEST_EQ_SIGNED(pthread_join(threads[i], nullptr), 0);

	TEST_EQ_UNSIGNED(atomic_load_explicit(&state.failures, memory_order_relaxed), 0);
}

int
main(void)
{
	RunThreadTest(ThrowExistingException);
	RunThreadTest(RaiseNewExceptions);

	return TestFinish();
}

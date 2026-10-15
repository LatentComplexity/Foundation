#define _POSIX_C_SOURCE 200809L

#import "Fixtures.h"
#import "Test.h"

#include <malloc.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>

typedef void (*Workload)(NSUInteger iterations);

typedef struct ResourceSnapshot {
	uint64_t residentBytes;
	uint64_t heapBytes;
	long peakKilobytes;
} ResourceSnapshot;

static volatile uint64_t Sink;

static uint64_t
ResidentBytes(void)
{
	FILE *status = fopen("/proc/self/statm", "r");
	unsigned long totalPages;
	unsigned long residentPages;
	long pageSize;

	if (status == nullptr)
		return 0;
	if (fscanf(status, "%lu %lu", &totalPages, &residentPages) != 2)
		residentPages = 0;
	(void)totalPages;
	fclose(status);

	pageSize = sysconf(_SC_PAGESIZE);
	return pageSize > 0 ? (uint64_t)residentPages * (uint64_t)pageSize : 0;
}

static ResourceSnapshot
Snapshot(void)
{
	struct mallinfo2 const heap = mallinfo2();
	struct rusage usage;

	(void)getrusage(RUSAGE_SELF, &usage);
	return (ResourceSnapshot){
		.residentBytes = ResidentBytes(),
		.heapBytes = (uint64_t)heap.uordblks + (uint64_t)heap.hblkhd,
		.peakKilobytes = usage.ru_maxrss
	};
}

static double
ElapsedNanoseconds(struct timespec start, struct timespec end)
{
	return (double)(end.tv_sec - start.tv_sec) * 1e9 + (double)(end.tv_nsec - start.tv_nsec);
}

static int64_t
ByteDelta(uint64_t before, uint64_t after)
{
	return after >= before ? (int64_t)(after - before) : -(int64_t)(before - after);
}

static void
Run(char const *name, Workload workload, NSUInteger iterations)
{
	ResourceSnapshot before;
	ResourceSnapshot after;
	struct timespec start;
	struct timespec end;
	double nanoseconds;
	int64_t residentDelta;
	int64_t heapDelta;

	(void)malloc_trim(0);
	before = Snapshot();
	(void)clock_gettime(CLOCK_MONOTONIC, &start);
	workload(iterations);
	(void)clock_gettime(CLOCK_MONOTONIC, &end);
	(void)malloc_trim(0);
	after = Snapshot();
	nanoseconds = ElapsedNanoseconds(start, end);
	residentDelta = ByteDelta(before.residentBytes, after.residentBytes);
	heapDelta = ByteDelta(before.heapBytes, after.heapBytes);

	printf("%-30s %10.1f ns/op  RSS %+.2f MiB  heap %+.2f MiB  peak %.2f MiB\n",
		name, nanoseconds / (double)iterations,
		(double)residentDelta / (1024.0 * 1024.0),
		(double)heapDelta / (1024.0 * 1024.0),
		(double)after.peakKilobytes / 1024.0);
}

static NSMethodSignature *
SignatureFor(SEL selector)
{
	return [InvocationSubject instanceMethodSignatureForSelector:selector];
}

static NSInvocation *
LongInvocation(InvocationSubject *subject)
{
	SEL const selector = @selector(echoLong:);
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:SignatureFor(selector)];

	invocation.target = subject;
	invocation.selector = selector;
	return invocation;
}

static void
DirectMessage(NSUInteger iterations)
{
	InvocationSubject *subject = [InvocationSubject new];

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		Sink += (uint64_t)[subject echoLong:(long)iteration];
}

static void
ReuseInvoke(NSUInteger iterations)
{
	InvocationSubject *subject = [InvocationSubject new];
	NSInvocation *invocation = LongInvocation(subject);

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration) {
		long value = (long)iteration;
		long result;

		[invocation setArgument:&value atIndex:2];
		[invocation invoke];
		[invocation getReturnValue:&result];
		Sink += (uint64_t)result;
	}
}

static void
ReuseInvokeUsingIMP(NSUInteger iterations)
{
	InvocationSubject *subject = [InvocationSubject new];
	NSInvocation *invocation = LongInvocation(subject);
	IMP implementation = class_getMethodImplementation([InvocationSubject class], @selector(echoLong:));

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration) {
		long value = (long)iteration;
		long result;

		[invocation setArgument:&value atIndex:2];
		[invocation invokeUsingIMP:implementation];
		[invocation getReturnValue:&result];
		Sink += (uint64_t)result;
	}
}

static void
ConstructAndInvoke(NSUInteger iterations)
{
	InvocationSubject *subject = [InvocationSubject new];

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		@autoreleasepool {
			NSInvocation *invocation = LongInvocation(subject);
			long value = (long)iteration;
			long result;

			[invocation setArgument:&value atIndex:2];
			[invocation invoke];
			[invocation getReturnValue:&result];
			Sink += (uint64_t)result;
		}
}

static void
HFAInvoke(NSUInteger iterations)
{
	InvocationSubject *subject = [InvocationSubject new];
	SEL const selector = @selector(bumpD4:);
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:SignatureFor(selector)];
	D4 input = { 1, 2, 3, 4 };

	invocation.target = subject;
	invocation.selector = selector;
	for (NSUInteger iteration = 0; iteration < iterations; ++iteration) {
		D4 output;

		input.a = (double)iteration;
		[invocation setArgument:&input atIndex:2];
		[invocation invoke];
		[invocation getReturnValue:&output];
		Sink += (uint64_t)output.a;
	}
}

static void
IndirectInvoke(NSUInteger iterations)
{
	InvocationSubject *subject = [InvocationSubject new];
	SEL const selector = @selector(bumpI40:);
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:SignatureFor(selector)];
	I40 input = { 1, 2, 3, 4, 5 };

	invocation.target = subject;
	invocation.selector = selector;
	for (NSUInteger iteration = 0; iteration < iterations; ++iteration) {
		I40 output;

		input.a = (long)iteration;
		[invocation setArgument:&input atIndex:2];
		[invocation invoke];
		[invocation getReturnValue:&output];
		Sink += (uint64_t)output.a;
	}
}

static void
FullForward(NSUInteger iterations)
{
	InvocationSubject *subject = [InvocationSubject new];
	InvocationSubject *proxy = (InvocationSubject *)[InvocationProxy proxyWithBacking:subject];

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		Sink += (uint64_t)[proxy echoLong:(long)iteration];
}

static void
RetainedObjectCycle(NSUInteger iterations)
{
	InvocationSubject *subject = [InvocationSubject new];
	SEL const selector = @selector(echoObject:);

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		@autoreleasepool {
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:SignatureFor(selector)];
			InvocationSentinel *sentinel = [InvocationSentinel new];
			__unsafe_unretained id returned = nil;

			invocation.target = subject;
			invocation.selector = selector;
			[invocation setArgument:&sentinel atIndex:2];
			[invocation retainArguments];
			[invocation invoke];
			[invocation getReturnValue:&returned];
			Sink += returned != nil;
		}
}

int
main(int argc, char **argv)
{
	NSUInteger iterations = 200000;
	char *end = nullptr;

	if (argc > 1) {
		unsigned long const requested = strtoul(argv[1], &end, 10);

		if (end != argv[1] && *end == '\0' && requested > 0)
			iterations = requested;
	}

	printf("NSInvocation benchmark: %lu iterations, one process\n", iterations);
	printf("RSS/heap are post-drain deltas; peak is the process-wide high-water mark.\n\n");
	Run("direct Objective-C message", DirectMessage, iterations);
	Run("reused -invoke", ReuseInvoke, iterations);
	Run("reused -invokeUsingIMP:", ReuseInvokeUsingIMP, iterations);
	Run("construct + invoke", ConstructAndInvoke, iterations);
	Run("four-double HFA", HFAInvoke, iterations);
	Run("40-byte indirect aggregate", IndirectInvoke, iterations);
	Run("full forwarding", FullForward, iterations);
	Run("retained object lifecycle", RetainedObjectCycle, MAX(iterations / 20, (NSUInteger)1));

	fprintf(stderr, "(sink=%lu, live sentinels=%d)\n", (unsigned long)Sink, InvocationSentinelLiveCount);
	TEST_EQ_SIGNED(InvocationSentinelLiveCount, 0);
	return TestFinish();
}

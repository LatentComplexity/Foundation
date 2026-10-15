#define _POSIX_C_SOURCE 200809L

#import <Foundation/NSData.h>
#import "Test.h"

#include <malloc.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>

typedef void (*Workload)(NSUInteger iterations, NSUInteger size);

typedef struct ResourceSnapshot {
	uint64_t residentBytes;
	uint64_t heapBytes;
	long peakKilobytes;
} ResourceSnapshot;

static volatile NSUInteger Sink;

static uint64_t
ResidentBytes(void)
{
	FILE *status;
	unsigned long totalPages;
	unsigned long residentPages;
	long pageSize;

	status = fopen("/proc/self/statm", "r");
	if (status == nullptr)
		return 0;

	if (fscanf(status, "%lu %lu", &totalPages, &residentPages) != 2)
		residentPages = 0;
	(void)totalPages;
	fclose(status);

	pageSize = sysconf(_SC_PAGESIZE);
	if (pageSize <= 0)
		return 0;

	return (uint64_t)residentPages * (uint64_t)pageSize;
}

static ResourceSnapshot
Snapshot(void)
{
	struct mallinfo2 const heap = mallinfo2();
	struct rusage usage;
	ResourceSnapshot snapshot;

	(void)getrusage(RUSAGE_SELF, &usage);
	snapshot.residentBytes = ResidentBytes();
	snapshot.heapBytes = (uint64_t)heap.uordblks + (uint64_t)heap.hblkhd;
	snapshot.peakKilobytes = usage.ru_maxrss;

	return snapshot;
}

static double
ElapsedNanoseconds(struct timespec start, struct timespec end)
{
	return (double)(end.tv_sec - start.tv_sec) * 1e9 +
		(double)(end.tv_nsec - start.tv_nsec);
}

static int64_t
ByteDelta(uint64_t before, uint64_t after)
{
	if (after >= before)
		return (int64_t)(after - before);

	return -(int64_t)(before - after);
}

static void
Run(char const *name, Workload workload, NSUInteger iterations, NSUInteger size)
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
	workload(iterations, size);
	(void)clock_gettime(CLOCK_MONOTONIC, &end);
	(void)malloc_trim(0);
	after = Snapshot();
	nanoseconds = ElapsedNanoseconds(start, end);
	residentDelta = ByteDelta(before.residentBytes, after.residentBytes);
	heapDelta = ByteDelta(before.heapBytes, after.heapBytes);

	printf("%-28s %10.1f ns/op  RSS %+.2f MiB  heap %+.2f MiB  peak %.2f MiB\n",
		name, nanoseconds / (double)iterations,
		(double)residentDelta / (1024.0 * 1024.0),
		(double)heapDelta / (1024.0 * 1024.0),
		(double)after.peakKilobytes / 1024.0);
}

[[clang::no_sanitize("integer")]]
static void
FillPattern(unsigned char *bytes, NSUInteger count)
{
	uint64_t state = UINT64_C(0x9e3779b97f4a7c15);

	for (NSUInteger index = 0; index < count; ++index) {
		state ^= state >> 12;
		state ^= state << 25;
		state ^= state >> 27;
		bytes[index] = (unsigned char)((state * UINT64_C(0x2545f4914f6cdd1d)) >> 56);
	}
}

static NSData *
Source(NSUInteger size)
{
	NSMutableData *source = [[NSMutableData alloc] initWithCount:size];

	FillPattern(source.mutableBytes, size);
	return [source copy];
}

static void
Construct(NSUInteger iterations, NSUInteger size)
{
	NSData *source = Source(size);

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		@autoreleasepool {
			NSData *data = [NSData dataWithBytes:source.bytes count:source.count];

			Sink += data.count;
		}
}

static void
MutableCopy(NSUInteger iterations, NSUInteger size)
{
	NSData *source = Source(size);

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		@autoreleasepool {
			NSMutableData *data = [source mutableCopy];

			Sink += data.count;
		}
}

static void
Subrange(NSUInteger iterations, NSUInteger size)
{
	NSData *source = Source(size);
	NSUInteger const span = size - size / 4;
	NSUInteger const positions = size - span + 1;

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		@autoreleasepool {
			NSData *data = [source subdataWithRange:NSRangeMake(iteration % positions, span)];

			Sink += data.count;
		}
}

static void
CopyThenWrite(NSUInteger iterations, NSUInteger size)
{
	NSData *source = Source(size);

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		@autoreleasepool {
			NSMutableData *data = [source mutableCopy];
			unsigned char byte = (unsigned char)iteration;

			[data replaceBytesInRange:NSRangeMake(iteration % size, 1) withBytes:&byte];
			Sink += data.count;
		}
}

static void
AppendChunks(NSUInteger iterations, NSUInteger size)
{
	NSData *source = Source(size);

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		@autoreleasepool {
			NSMutableData *data = [[NSMutableData alloc] initWithCapacity:0];
			NSUInteger offset = 0;

			while (offset < size) {
				NSUInteger const count = MIN((NSUInteger)64, size - offset);

				[data appendBytes:(unsigned char const *)source.bytes + offset count:count];
				offset += count;
			}
			Sink += data.count;
		}
}

static void
Search(NSUInteger iterations, NSUInteger size)
{
	NSMutableData *mutable = [[NSMutableData alloc] initWithCount:size];
	NSData *needle = [NSData dataWithBytes:"needle!!" count:8];
	NSData *source;

	memset(mutable.mutableBytes, 'a', size);
	memcpy((unsigned char *)mutable.mutableBytes + size - needle.count, needle.bytes, needle.count);
	source = [mutable copy];

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		@autoreleasepool {
			NSRange const range = [source rangeOfData:needle options:NSDataSearchDefault
				range:NSRangeMake(0, source.count)];

			Sink += range.location;
		}
}

static void
Fanout(NSUInteger iterations, NSUInteger size)
{
	NSData *source = Source(size);

	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		@autoreleasepool {
			NSMutableData *copies[64] = { nil };

			for (NSUInteger index = 0; index < 64; ++index)
				copies[index] = [source mutableCopy];
			for (NSUInteger index = 0; index < 64; ++index) {
				unsigned char byte = (unsigned char)(iteration ^ index);

				[copies[index] replaceBytesInRange:NSRangeMake(index % size, 1) withBytes:&byte];
			}
			Sink += copies[63].count;
		}
}

static void
MemoryTorture(NSUInteger iterations, NSUInteger size)
{
	for (NSUInteger iteration = 0; iteration < iterations; ++iteration)
		@autoreleasepool {
			NSData *source = Source(size);
			NSMutableData *copies[64] = { nil };

			for (NSUInteger index = 0; index < 64; ++index) {
				unsigned char byte = (unsigned char)(iteration ^ index);

				copies[index] = [source mutableCopy];
				[copies[index] replaceBytesInRange:NSRangeMake(index, 1) withBytes:&byte];
			}
			Sink += copies[63].count;
		}
}

int
main(int argc, char **argv)
{
	NSUInteger iterations = 2000;
	NSUInteger const size = 64 * 1024;
	char *end = nullptr;

	if (argc > 1) {
		unsigned long const requested = strtoul(argv[1], &end, 10);

		if (end != argv[1] && *end == '\0' && requested > 0)
			iterations = (NSUInteger)requested;
	}

	@autoreleasepool {
		NSData *probe = Source(256);

		TEST_EQ_UNSIGNED(probe.count, 256);
		TEST(probe.bytes != nullptr);
	}

	printf("NSData benchmark: %lu iterations, %lu-byte payload, one process\n",
		iterations, size);
	printf("RSS/heap are post-drain deltas; peak is the process-wide high-water mark.\n\n");
	Run("dataWithBytes:count:", Construct, iterations, size);
	Run("mutableCopy", MutableCopy, iterations, size);
	Run("subdataWithRange:", Subrange, iterations, size);
	Run("mutableCopy + 1-byte write", CopyThenWrite, iterations, size);
	Run("appendBytes:count: chunks", AppendChunks, MAX(iterations / 20, (NSUInteger)1), size);
	Run("rangeOfData: forward", Search, iterations, size);
	Run("64-way CoW fanout", Fanout, MAX(iterations / 50, (NSUInteger)1), size);
	Run("64 MiB live CoW torture", MemoryTorture, 1, 1024 * 1024);

	fprintf(stderr, "(sink=%lu)\n", Sink);
	return TestFinish();
}

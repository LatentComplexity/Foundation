
#include <FoundationPrivate/Routines/NSMutex.h>

#ifdef __linux__
#ifndef __USE_MISC
#define __USE_MISC
#endif
#include <sys/syscall.h>
#include <linux/futex.h>
#include <unistd.h>
#elifdef __OpenBSD__
#include <sys/time.h>
#include <sys/futex.h>
#endif

void
NSMutexLock(NSMutex *m)
{
	unsigned int c;

	c = NSMutexStateUnlocked;

	/* First time coming here? */
	if (OSAtomicCompareAndSwap(&m->state, &c, NSMutexStateLocked, OSAtomicMemoryOrderAcquire,
	    OSAtomicMemoryOrderRelaxed))
		return;

	/* I think I'll stick around for a little while... */
	for (int spin = 0; spin < 100; ++spin) {
		if (OSAtomicLoad(&m->state, OSAtomicMemoryOrderRelaxed) == NSMutexStateUnlocked) {
			c = NSMutexStateUnlocked;
			if (OSAtomicCompareAndSwap(&m->state, &c, NSMutexStateLocked, OSAtomicMemoryOrderAcquire,
			    OSAtomicMemoryOrderRelaxed))
				return;
		}

#if defined(__x86_64) || (defined(__riscv) && __riscv_xlen == 64)
		__asm__ volatile("pause" : : : "memory");
#elif defined(__aarch64__) || defined(__arm64__)
		__asm__ volatile("isb" : : : "memory");
#else
#error "Unsupported architecture!"
#endif
	}

	/* You never showed up. */
	if (c != NSMutexStateContended)
		c = OSAtomicSwap(&m->state, NSMutexStateContended,
					OSAtomicMemoryOrderAcquire);

	/* Good-bye. You're up to no good, anyways. */
	while (c != NSMutexStateUnlocked) {
#ifdef __linux__
		syscall(SYS_futex, &m->state, FUTEX_WAIT_PRIVATE, NSMutexStateContended, nullptr, nullptr, 0);
#elif __OpenBSD__
		futex(&m->state, FUTEX_WAIT_PRIVATE, NSMutexStateContended, nullptr, nullptr);
#else
#error "Unsupported platform!"
#endif
		c = OSAtomicSwap(&m->state, NSMutexStateContended, OSAtomicMemoryOrderAcquire);
	}
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wimplicit-int-enum-cast"

void
NSMutexUnlock(NSMutex *m)
{
	/* Was I the only one holding the lock? */
	if (OSAtomicSubtract(&m->state, 1, OSAtomicMemoryOrderRelease) == NSMutexStateLocked)
		return;

	/* Somebody else was waiting; wake up. */
	OSAtomicStore(&m->state, NSMutexStateUnlocked, OSAtomicMemoryOrderRelaxed);

#ifdef __linux__
	syscall(SYS_futex, &m->state, FUTEX_WAKE_PRIVATE, 1, nullptr, nullptr, 0);
#elif __OpenBSD__
	futex(&m->state, FUTEX_WAKE_PRIVATE, 1, nullptr, nullptr);
#else
#error "Unsupported platform!"
#endif
}

#pragma clang diagnostic pop

void
NSRecursiveMutexLock(NSRecursiveMutex *m)
{
	uintptr_t self;

#ifdef __x86_64
	__asm__ volatile("mov %%fs:0, %0" : "=r"(self));
#elif defined(__riscv) && __riscv_xlen == 64
	__asm__ volatile("mv %0, tp" : "=r"(self));
#elif defined(__aarch64__) || defined(__arm64__)
	__asm__ volatile("mrs %0, tpidr_el0" : "=r"(self));
#else
#error "Unsupported architecture!"
#endif

	if (self == m->owner) {
		if (__builtin_add_overflow(m->count, 1, &m->count))
			abort();

		return;
	}

	NSMutexLock((NSMutex *)m);

	m->count = 1;
	m->owner = self;
}

void
NSRecursiveMutexUnlock(NSRecursiveMutex *m)
{
	if (__builtin_sub_overflow(m->count, 1, &m->count))
		abort();

	if (m->count > 0)
		return;

	m->owner = 0;

	NSMutexUnlock((NSMutex *)m);
}

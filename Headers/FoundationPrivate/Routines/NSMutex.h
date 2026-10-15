
#include <Foundation/NSObjCRuntime.h>
#include <FoundationPrivate/Routines/OSAtomic.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum NSMutexState : unsigned int {
	NSMutexStateUnlocked = 0,
	NSMutexStateLocked = 1,
	NSMutexStateContended = 2
} NSMutexState;

typedef struct NSMutex {
	NSMutexState _Atomic state;
} NSMutex;

typedef struct NSRecursiveMutex {
	NSMutexState _Atomic state;
	unsigned int count;
	uintptr_t owner;
} NSRecursiveMutex;

[[clang::always_inline]]
static inline void
NSMutexInit(NSMutex *m)
{
	OSAtomicInit(&m->state, NSMutexStateUnlocked);
}

void
NSMutexLock(NSMutex *);

void
NSMutexUnlock(NSMutex *);

[[clang::always_inline]]
static inline void
NSRecursiveMutexInit(NSRecursiveMutex *m)
{
	OSAtomicInit(&m->state, NSMutexStateUnlocked);
	m->count = 0;
	m->owner = 0;
}

void
NSRecursiveMutexLock(NSRecursiveMutex *);

void
NSRecursiveMutexUnlock(NSRecursiveMutex *);

NS_ASSUME_NONNULL_END


#include <FoundationPrivate/Routines/NSCallOnce.h>

void
NSCallOnce(NSCallOnceState *state, __attribute__((noescape)) void (^block)(void))
{
	if (OSAtomicLoad(&state->wasCalled, OSAtomicMemoryOrderRelaxed) == true)
		return;

	NSMutexLock(&state->mutex);

	if (OSAtomicLoad(&state->wasCalled, OSAtomicMemoryOrderRelaxed) == false) {
		block();
		OSAtomicStore(&state->wasCalled, true, OSAtomicMemoryOrderRelease);
	}

	NSMutexUnlock(&state->mutex);
}

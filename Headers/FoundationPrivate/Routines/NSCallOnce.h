
#import <FoundationPrivate/Routines/NSMutex.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct NSCallOnceState {
	NSMutex mutex;
	bool _Atomic wasCalled;
	char padding[3];
} NSCallOnceState;

[[clang::always_inline]]
static inline void
NSCallOnceInit(NSCallOnceState *s)
{
	NSMutexInit(&s->mutex);
	OSAtomicInit(&s->wasCalled, false);
}

void
NSCallOnce(NSCallOnceState *, __attribute__((noescape)) void (^)(void));

NS_ASSUME_NONNULL_END

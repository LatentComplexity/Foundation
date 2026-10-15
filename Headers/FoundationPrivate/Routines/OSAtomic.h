
_Pragma("clang assume_nonnull begin")

typedef enum OSAtomicMemoryOrderValues : int {
	OSAtomicMemoryOrderRelaxed = __ATOMIC_RELAXED,
	OSAtomicMemoryOrderConsume = __ATOMIC_CONSUME,
	OSAtomicMemoryOrderAcquire = __ATOMIC_ACQUIRE,
	OSAtomicMemoryOrderRelease = __ATOMIC_RELEASE,
	OSAtomicMemoryOrderAcqRel = __ATOMIC_ACQ_REL,
	OSAtomicMemoryOrderSeqCst = __ATOMIC_SEQ_CST
} OSAtomicMemoryOrderValues;

#define OSAtomicInit(obj, desired) __c11_atomic_init(obj, desired)

#define OSAtomicCompilerBarrier(v) __c11_atomic_signal_fence(v)
#define OSAtomicThreadFence(v) __c11_atomic_thread_fence(v)

#define OSAtomicLoad(...) OSAtomicLoadImpl(__VA_ARGS__,			       \
						OSAtomicMemoryOrderSeqCst)
#define OSAtomicLoadImpl(obj, memoryOrder, ...)				       \
	__c11_atomic_load(obj, memoryOrder)

#define OSAtomicStore(...) OSAtomicStoreImpl(__VA_ARGS__,		       \
						OSAtomicMemoryOrderSeqCst)
#define OSAtomicStoreImpl(obj, desired, memoryOrder, ...)		       \
	__c11_atomic_store(obj, desired, memoryOrder)

#define OSAtomicAdd(...) OSAtomicAddImpl(__VA_ARGS__,			       \
						OSAtomicMemoryOrderSeqCst)
#define OSAtomicAddImpl(obj, operand, memoryOrder, ...)			       \
	__c11_atomic_fetch_add(obj, operand, memoryOrder)

#define OSAtomicSubtract(...) OSAtomicSubtractImpl(__VA_ARGS__,		       \
						OSAtomicMemoryOrderSeqCst)
#define OSAtomicSubtractImpl(obj, operand, memoryOrder, ...)		       \
	__c11_atomic_fetch_sub(obj, operand, memoryOrder)

#define OSAtomicAND(...) OSAtomicANDImpl(__VA_ARGS__,			       \
						OSAtomicMemoryOrderSeqCst)
#define OSAtomicANDImpl(obj, operand, memoryOrder, ...)			       \
	__c11_atomic_fetch_and(obj, operand, memoryOrder)

#define OSAtomicOR(...) OSAtomicORImpl(__VA_ARGS__,			       \
						OSAtomicMemoryOrderSeqCst)
#define OSAtomicORImpl(obj, operand, memoryOrder, ...)			       \
	__c11_atomic_fetch_or(obj, operand, memoryOrder)

#define OSAtomicXOR(...) OSAtomicXORImpl(__VA_ARGS__,			       \
						OSAtomicMemoryOrderSeqCst)
#define OSAtomicXORImpl(obj, operand, memoryOrder, ...)			       \
	__c11_atomic_fetch_xor(obj, operand, memoryOrder)

#define OSAtomicSwap(...) OSAtomicSwapImpl(__VA_ARGS__,			       \
						OSAtomicMemoryOrderSeqCst)
#define OSAtomicSwapImpl(obj, desired, memoryOrder, ...)		       \
	__c11_atomic_exchange(obj, desired, memoryOrder)

#define OSAtomicCompareAndSwap(...) OSAtomicCompareAndSwapImpl(__VA_ARGS__,    \
						OSAtomicMemoryOrderSeqCst,     \
						OSAtomicMemoryOrderSeqCst)
#define OSAtomicCompareAndSwapImpl(obj, expected, desired, success, fail, ...) \
	__c11_atomic_compare_exchange_strong(obj, expected, desired,	       \
						success, fail)

_Pragma("clang assume_nonnull end")

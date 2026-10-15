
#include <FoundationPrivate/Routines/NSRandom.h>

#ifndef __USE_MISC
#define __USE_MISC
#endif

#include <sys/mman.h>
#include <sys/random.h>
#include <unistd.h>
#include <string.h>

/* ChaCha20 in keystream mode (the secret key and nonce are just entropy, nothing cryptographic happens here.) */
void
ChaCha20RandomBlocks(unsigned int ChaCha20State[static 16], char *randomBytes, NSUInteger blockCount);

/*
 * ChaCha20 emits 64-byte blocks. We refill our buffer a whole batch of blocks at a time so that the bulk (multi-block)
 * path of ChaCha20RandomBlocks() does the work, rather than its slower one-block-at-a-time tail.
 *
 * Effective throughput is already within a fraction of a percent (99.3%) at three blocks (the arm64 kernel's group
 * size); beyond that, a larger buffer only buys fewer, less frequent refills. Fifteen blocks (a multiple of three
 * about 1 KiB in size) keeps refills infrequent while wasting little memory or precomputed entropy on short-lived
 * threads.
 *
 * TODO: Maybe this deserves being raised to ~60 blocks? If mmap() allocates a page for us, we might as well use the
 * TODO: whole page, no?
 */
enum : NSUInteger {
	NSRandomBlockByteCount = 64,
	NSRandomBufferBlockCount = 15,
	NSRandomBufferByteCount = NSRandomBlockByteCount * NSRandomBufferBlockCount
};

/*
 * Each refill reserves its trailing 48 bytes to re-key the cipher with a fresh key and nonce in place from the very
 * same keystream. Because the new key is a one-way function if the old one, a later compromise of the live state
 * cannot reconstruct any output previously handed out before the most recent refill. Callers consume from the back
 * of the buffer down towards remainingRandomBytes == 0. The reserve is, obviously, never returned to a caller.
 */
enum : NSUInteger {
	NSRandomRekeyByteCount = 48,
	NSRandomUsableByteCount = NSRandomBufferByteCount - NSRandomRekeyByteCount
};

typedef struct NSRandomContext {
	unsigned int ChaCha20State[16];
	NSUInteger remainingRandomBytes;
	NSUInteger remainingRandomBlocks;
	char randomBytes[NSRandomBufferByteCount];
} NSRandomContext;

static_assert(offsetof(NSRandomContext, ChaCha20State) % 16 == 0, "ChaCha20State must be 16-byte aligned!");

/* The literal ASCII string: "expand 32-byte k" used as a constant. */
static unsigned char constexpr expand32bytek[16] = { 0x65, 0x78, 0x70, 0x61,
						     0x6e, 0x64, 0x20, 0x33,
						     0x32, 0x2d, 0x62, 0x79,
						     0x74, 0x65, 0x20, 0x6b };

static thread_local NSRandomContext *c = nullptr;

[[clang::always_inline]]
static inline void
NSRandomReseed(void)
{
	/*
	 * Initialize ChaCha20's internal state; start with the constant.
	 * TODO: this initialization need only be done once, but moving 16 bytes surely can't be the bottleneck here,
	 * TODO: right?
	 */
	__builtin_memcpy_inline(&c->ChaCha20State, expand32bytek, sizeof(expand32bytek));

	/* Fill in the other 48 bytes with random values. This sets both the secret key and the nonce. */
	if (getentropy(&c->ChaCha20State[4], sizeof(c->ChaCha20State) - 4 * sizeof(unsigned int)) == -1)
		_exit(1);

	/*
	 * Reseed after 4 to 8 MiB worth of random blocks. 4 MiB / 64 bytes gives 65,536 blocks; use the entropy in the
	 * twelfth word as the dividend for calculating c->ChaCha20State[12] % c->remainingRandomBlocks quickly.
	 */
	c->remainingRandomBlocks = 4194304 / NSRandomBlockByteCount;
	c->remainingRandomBlocks += c->ChaCha20State[12] & (65535 - 1);

	/* The twelfth word is used as a block counter. Reset it back to zero after making use of it above. */
	c->ChaCha20State[12] = 0;
}

[[clang::always_inline]]
static inline void
NSRandomRefill(void)
{
	/*
	 * Reseed before refilling whenever this key+nonce pair cannot cover an entire buffer's worth of blocks, so
	 * that we never emit more blocks under one key than its budget allows (and never underflow the count by
	 * charging a whole buffer against a smaller remainder.) Reseeding at most a buffer early against a 4-to-8 MiB
	 * budget leaves the effective reseed interval unchanged, and it's cheap enough for 15 blocks.
	 *
	 * TODO: If the block count ever changes to, say, sixty, one should reconsider this simple check for something
	 * TODO: along the lines of what exists in NSRandomBytes().
	 */
	if (c->remainingRandomBlocks < NSRandomBufferBlockCount)
		NSRandomReseed();

	/* Refill our buffer and charge for it. */
	ChaCha20RandomBlocks(c->ChaCha20State, c->randomBytes, NSRandomBufferBlockCount);
	c->remainingRandomBlocks -= NSRandomBufferBlockCount;

	/*
	 * Re-key from the reserved trailing bytes of this fresh keystream. Wipe their bytes out of the buffer so they
	 * are never handed out. The previous key is now unrecoverable, so nothing produced before this refill can be
	 * reconstructed from the live state.
	 */
	memcpy(&c->ChaCha20State[4], &c->randomBytes[NSRandomUsableByteCount], NSRandomRekeyByteCount);
	c->ChaCha20State[12] = 0;
	explicit_bzero(&c->randomBytes[NSRandomUsableByteCount], NSRandomRekeyByteCount);

	/* Everything before the reserved tail is available to callers, consumed downwards. */
	c->remainingRandomBytes = NSRandomUsableByteCount;
}

[[clang::always_inline]]
static inline void
NSRandomInit(void)
{
	/* Don't reinitialize if the thread has already been here. */
	if (c != nullptr)
		return;

	/* Otherwise, allocate memory to store the context. */
	if ((c = mmap(nullptr, sizeof(*c), PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0)) == MAP_FAILED)
		_exit(1);

	/* Force new threads to create their own random number state. */
#ifdef __linux__
	if (madvise(c, sizeof(*c), MADV_WIPEONFORK) == -1)
#elifdef __OpenBSD__
	if (minherit(c, sizeof(*c), MAP_INHERIT_ZERO) == -1)
#else
#error "Unsupported platform!"
#endif
		_exit(1);

	/* Fill in some random bytes. */
	NSRandomRefill();
}

void
NSRandomBytes(void *bytes, NSUInteger length)
{
	NSUInteger blockCount;
	NSUInteger byteCount;
	NSUInteger copySize;

	NSRandomInit();

	/* Find how many block-sized bytes we want, and how many extra random bytes we want. */
	blockCount = length / NSRandomBlockByteCount;
	byteCount = length % NSRandomBlockByteCount;

	/* Directly generate random bytes for block-sized output. */
	while (blockCount != 0) {
		if (c->remainingRandomBlocks == 0)
			NSRandomReseed();

		copySize = MIN(blockCount, c->remainingRandomBlocks);
		ChaCha20RandomBlocks(c->ChaCha20State, bytes, copySize);

		bytes = (char *)bytes + copySize * NSRandomBlockByteCount;
		c->remainingRandomBlocks -= copySize;
		blockCount -= copySize;
	}

	/*
	 * Any blocks above went straight into the caller's buffer without re-keying, so the live state could still
	 * reproduce them. Re-key just as a refill does: draw one fresh block and set the bytes. Wipe the block from
	 * the stack once finished.
	 */
	if (length >= NSRandomBlockByteCount) {
		char seed[NSRandomBlockByteCount];

		if (c->remainingRandomBlocks == 0)
			NSRandomReseed();

		ChaCha20RandomBlocks(c->ChaCha20State, seed, 1);
		c->remainingRandomBlocks--;
		memcpy(&c->ChaCha20State[4], seed, NSRandomRekeyByteCount);
		c->ChaCha20State[12] = 0;
		explicit_bzero(seed, sizeof(seed));
	}

	/* Pull random bytes from buffer for sub block-sized output. */
	while (byteCount != 0) {
		if (c->remainingRandomBytes == 0)
			NSRandomRefill();

		/* Find how many bytes we can yank; drag the index down, and copy. */
		copySize = MIN(byteCount, c->remainingRandomBytes);
		c->remainingRandomBytes -= copySize;
		memcpy(bytes, &c->randomBytes[c->remainingRandomBytes], copySize);

		/* Wipe what we just handed out so a later compromise cannot read it back out of the buffer. */
		explicit_bzero(&c->randomBytes[c->remainingRandomBytes], copySize);

		bytes = (char *)bytes + copySize;
		byteCount -= copySize;
	}
}

NSUInteger
NSRandom(void)
{
	NSUInteger r;

	NSRandomBytes(&r, sizeof(NSUInteger));

	return r;
}

NSUInteger
NSRandomUniform(NSUInteger upperBound)
{
	NSUInteger r, threshold;

	if (upperBound < 2)
		return 0;

	threshold = NSUIntegerMax - (NSUIntegerMax % upperBound);

	while (true)
		if ((r = NSRandom()) < threshold)
			return r % upperBound;
}

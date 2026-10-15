
//
// Each of the four matrix rows occupies one 128-bit vector and the column/diagonal rounds are expressed as in-lane
// rotations. There are two refinements over the obvious implementation:
//
// * The 16 and 8-bit lane rotations use single instructions (REV32, TBL) instead of a shift/shift/or triple.
// * The main loop processes three independent blocks per iteration, their instructions interleaved, so the
//   out-of-order core can overlap the otherwise strictly serial quarter-round dependency chain across blocks. A
//   scalar tail handles the remaining (block count mod 3) blocks, so a single-block refill still runs the cheap
//   one-block path with no overhead.
//
// Every vector register used is caller-saved (v0-v7, v16-v31), so this remains a frameless leaf.
//

	.section .text
	.balign 16

	// Three-wide building blocks. Each applies one quarter-round step across all three blocks; the three
	// independent operations are issued back-to-back to hide their latency.

	// a += b ; d ^= a ; d = rotl(d, 16), the last as a halfword swap through REV32.
	.macro AXR16_3 a0, a1, a2, b0, b1, b2, d0, d1, d2
		add		\a0\().4s, \a0\().4s, \b0\().4s
		add		\a1\().4s, \a1\().4s, \b1\().4s
		add		\a2\().4s, \a2\().4s, \b2\().4s
		eor		\d0\().16b, \d0\().16b, \a0\().16b
		eor		\d1\().16b, \d1\().16b, \a1\().16b
		eor		\d2\().16b, \d2\().16b, \a2\().16b
		rev32		\d0\().8h, \d0\().8h
		rev32		\d1\().8h, \d1\().8h
		rev32		\d2\().8h, \d2\().8h
	.endm

	// a += b ; d ^= a ; d = rotl(d, 8), the last as a byte permutation using tbl, index in v27.
	.macro AXR8_3 a0, a1, a2, b0, b1, b2, d0, d1, d2
		add		\a0\().4s, \a0\().4s, \b0\().4s
		add		\a1\().4s, \a1\().4s, \b1\().4s
		add		\a2\().4s, \a2\().4s, \b2\().4s
		eor		\d0\().16b, \d0\().16b, \a0\().16b
		eor		\d1\().16b, \d1\().16b, \a1\().16b
		eor		\d2\().16b, \d2\().16b, \a2\().16b
		tbl		\d0\().16b, { \d0\().16b }, v27.16b
		tbl		\d1\().16b, { \d1\().16b }, v27.16b
		tbl		\d2\().16b, { \d2\().16b }, v27.16b
	.endm

	// c += d ; b ^= c ; b = rotl(b, amt), the rotate spliced from a shift pair (scratch in t.)
	.macro AXRS_3 amt, c0, c1, c2, d0, d1, d2, b0, b1, b2, t0, t1, t2
		add		\c0\().4s, \c0\().4s, \d0\().4s
		add		\c1\().4s, \c1\().4s, \d1\().4s
		add		\c2\().4s, \c2\().4s, \d2\().4s
		eor		\b0\().16b, \b0\().16b, \c0\().16b
		eor		\b1\().16b, \b1\().16b, \c1\().16b
		eor		\b2\().16b, \b2\().16b, \c2\().16b
		shl		\t0\().4s, \b0\().4s, #\amt
		shl		\t1\().4s, \b1\().4s, #\amt
		shl		\t2\().4s, \b2\().4s, #\amt
		ushr		\b0\().4s, \b0\().4s, #(32 - \amt)
		ushr		\b1\().4s, \b1\().4s, #(32 - \amt)
		ushr		\b2\().4s, \b2\().4s, #(32 - \amt)
		orr		\b0\().16b, \b0\().16b, \t0\().16b
		orr		\b1\().16b, \b1\().16b, \t1\().16b
		orr		\b2\().16b, \b2\().16b, \t2\().16b
	.endm

	.macro QuarterRound3 a0, a1, a2, b0, b1, b2, c0, c1, c2, d0, d1, d2, t0, t1, t2
		AXR16_3		\a0, \a1, \a2, \b0, \b1, \b2, \d0, \d1, \d2
		AXRS_3	12,	\c0, \c1, \c2, \d0, \d1, \d2, \b0, \b1, \b2, \t0, \t1, \t2
		AXR8_3		\a0, \a1, \a2, \b0, \b1, \b2, \d0, \d1, \d2
		AXRS_3	7,	\c0, \c1, \c2, \d0, \d1, \d2, \b0, \b1, \b2, \t0, \t1, \t2
	.endm

	// Rotate the lanes of all three blocks' shared row by \amt bytes (ext is a whole-element lane rotate.)
	.macro Ext3 amt, v0, v1, v2
		ext		\v0\().16b, \v0\().16b, \v0\().16b, #\amt
		ext		\v1\().16b, \v1\().16b, \v1\().16b, #\amt
		ext		\v2\().16b, \v2\().16b, \v2\().16b, #\amt
	.endm

	.macro DoubleRound3 a0, a1, a2, b0, b1, b2, c0, c1, c2, d0, d1, d2, t0, t1, t2
		QuarterRound3	\a0, \a1, \a2, \b0, \b1, \b2, \c0, \c1, \c2, \d0, \d1, \d2, \t0, \t1, \t2
		Ext3	4,	\b0, \b1, \b2				// {1, 2, 3, 0}
		Ext3	8,	\c0, \c1, \c2				// {2, 3, 0, 1}
		Ext3	12,	\d0, \d1, \d2				// {3, 0, 1, 2}
		QuarterRound3	\a0, \a1, \a2, \b0, \b1, \b2, \c0, \c1, \c2, \d0, \d1, \d2, \t0, \t1, \t2
		Ext3	12,	\b0, \b1, \b2				// {3, 0, 1, 2}
		Ext3	8,	\c0, \c1, \c2				// {2, 3, 0, 1}
		Ext3	4,	\d0, \d1, \d2				// {1, 2, 3, 0}
	.endm

	// One-wide kernel, used by the tail to mop up the (block count mod 3) remainder.
	.macro StraightRound a, b, c, d, tmp
		add		\a\().4s, \a\().4s, \b\().4s
		eor		\d\().16b, \d\().16b, \a\().16b
		rev32		\d\().8h, \d\().8h

		add		\c\().4s, \c\().4s, \d\().4s
		eor		\b\().16b, \b\().16b, \c\().16b
		shl		\tmp\().4s, \b\().4s, #12
		ushr		\b\().4s, \b\().4s, #20
		orr		\b\().16b, \b\().16b, \tmp\().16b

		add		\a\().4s, \a\().4s, \b\().4s
		eor		\d\().16b, \d\().16b, \a\().16b
		tbl		\d\().16b, { \d\().16b }, v27.16b

		add		\c\().4s, \c\().4s, \d\().4s
		eor		\b\().16b, \b\().16b, \c\().16b
		shl		\tmp\().4s, \b\().4s, #7
		ushr		\b\().4s, \b\().4s, #25
		orr		\b\().16b, \b\().16b, \tmp\().16b
	.endm

	.macro ChaCha20_1 a, b, c, d, tmp
	.rep 10
		StraightRound	\a, \b, \c, \d, \tmp
		ext		\b\().16b, \b\().16b, \b\().16b, #4
		ext		\c\().16b, \c\().16b, \c\().16b, #8
		ext		\d\().16b, \d\().16b, \d\().16b, #12
		StraightRound	\a, \b, \c, \d, \tmp
		ext		\b\().16b, \b\().16b, \b\().16b, #12
		ext		\c\().16b, \c\().16b, \c\().16b, #8
		ext		\d\().16b, \d\().16b, \d\().16b, #4
	.endr
	.endm

	.globl ChaCha20RandomBlocks
	.hidden ChaCha20RandomBlocks
	.type ChaCha20RandomBlocks, @function

ChaCha20RandomBlocks:
	.cfi_startproc
	bti	c
	// NSRandom guarantees that we are never called with a zero-length request. We are also guaranteed to
	// operate on aligned memory, courtesy of mmap().
	// x0 = state, x1 = output buffer, x2 = block count.
	// Hold the shared original rows 0-2 in v28-v30 and the running counter row (row 3) in v31. These survive
	// for the whole call. (v8-v15 are callee-saved, so we deliberately stay clear of them.)
	ldr	q28, [x0]
	ldr	q29, [x0, #16]
	ldr	q30, [x0, #32]
	ldr	q31, [x0, #48]

	// Build the block-counter increment vector {1, 0, 0, 0} in v26.
	movi	v26.4s, #0
	mov	w3, #1
	mov	v26.s[0], w3

	// Load the byte-permutation index used by the rotate-left-by-8 (TBL) into v27.
	adrp	x3, .Lrot8index
	add	x3, x3, :lo12:.Lrot8index
	ldr	q27, [x3]

	// If fewer than three blocks are requested, skip straight to the one-at-a-time tail.
	cmp	x2, #3
	b.lo	tailLoopSetup

	// Main loop: three independent blocks per iteration.
	// block 0:  a=v0  b=v1  c=v2  d=v3  t=v4  r3=v5
	// block 1:  a=v6  b=v7  c=v16 d=v17 t=v18 r3=v19
	// block 2:  a=v20 b=v21 c=v22 d=v23 t=v24 r3=v25
vectorLoop:
	// Seed each block from the shared rows; the three row-3 values differ only by the counter (ctr, ctr + 1,
	// ctr + 2). Keep each block's original row 3 (r3) around for the post-round add-back.
	mov	v0.16b, v28.16b
	mov	v1.16b, v29.16b
	mov	v2.16b, v30.16b
	mov	v3.16b, v31.16b
	mov	v5.16b, v31.16b

	mov	v6.16b, v28.16b
	mov	v7.16b, v29.16b
	mov	v16.16b, v30.16b
	add	v19.4s, v31.4s, v26.4s
	mov	v17.16b, v19.16b

	mov	v20.16b, v28.16b
	mov	v21.16b, v29.16b
	mov	v22.16b, v30.16b
	add	v25.4s, v19.4s, v26.4s
	mov	v23.16b, v25.16b

	// Dance, dance, dance! Ten interleaved double-rounds across the three blocks.
	.rep 10
		DoubleRound3	v0, v6, v20, v1, v7, v21, v2, v16, v22, v3, v17, v23, v4, v18, v24
	.endr

	// Add the original rows back to each block.
	add	v0.4s, v0.4s, v28.4s
	add	v1.4s, v1.4s, v29.4s
	add	v2.4s, v2.4s, v30.4s
	add	v3.4s, v3.4s, v5.4s
	add	v6.4s, v6.4s, v28.4s
	add	v7.4s, v7.4s, v29.4s
	add	v16.4s, v16.4s, v30.4s
	add	v17.4s, v17.4s, v19.4s
	add	v20.4s, v20.4s, v28.4s
	add	v21.4s, v21.4s, v29.4s
	add	v22.4s, v22.4s, v30.4s
	add	v23.4s, v23.4s, v25.4s

	// Store these random bytes (three 64-byte blocks in stream order).
	stp	q0, q1, [x1]
	stp	q2, q3, [x1, #32]
	stp	q6, q7, [x1, #64]
	stp	q16, q17, [x1, #96]
	stp	q20, q21, [x1, #128]
	stp	q22, q23, [x1, #160]

	// Advance the counter base by three (ctr = (ctr + 2) + 1), step the pointer, and loop while >= 3 remain.
	add	v31.4s, v25.4s, v26.4s
	add	x1, x1, #192
	sub	x2, x2, #3
	cmp	x2, #3
	b.hs	vectorLoop

tailLoopSetup:
	// Mop up the remaining zero, one, or two blocks one at a time.
	cbz	x2, done
tailLoop:
	mov	v0.16b, v28.16b
	mov	v1.16b, v29.16b
	mov	v2.16b, v30.16b
	mov	v3.16b, v31.16b

	ChaCha20_1	v0, v1, v2, v3, v4

	add	v0.4s, v0.4s, v28.4s
	add	v1.4s, v1.4s, v29.4s
	add	v2.4s, v2.4s, v30.4s
	add	v3.4s, v3.4s, v31.4s

	stp	q0, q1, [x1]
	stp	q2, q3, [x1, #32]

	add	v31.4s, v31.4s, v26.4s
	add	x1, x1, #64
	subs	x2, x2, #1
	b.ne	tailLoop

done:
	// We are all done. Store the block counter (low lane of row 3) back into the state.
	str	s31, [x0, #48]
	ret
	.cfi_endproc

	// The rotate-left-by-8 byte-permutation index: within each 32-bit lane, {b0,b1,b2,b3} -> {b3,b0,b1,b2}.
	.section .rodata
	.balign 16
.Lrot8index:
	.byte 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14

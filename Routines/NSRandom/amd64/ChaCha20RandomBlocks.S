
//
// Entirely unoptimized, see arm64 version for an idea on how this should look like.
//

	.section .text
	.balign 16, 0x90

	.macro StraightRound a, b, c, d, t0, t1
		vpaddd		\b, \a, \a
		vpxor		\a, \d, \d
		vpslld		$16, \d, \t0
		vpsrld		$16, \d, \t1
		vpor		\t0, \t1, \d

		vpaddd		\d, \c, \c
		vpxor		\c, \b, \b
		vpslld		$12, \b, \t0
		vpsrld		$20, \b, \t1
		vpor		\t0, \t1, \b

		vpaddd		\b, \a, \a
		vpxor		\a, \d, \d
		vpslld		$8, \d, \t0
		vpsrld		$24, \d, \t1
		vpor		\t0, \t1, \d

		vpaddd		\d, \c, \c
		vpxor		\c, \b, \b
		vpslld		$7, \b, \t0
		vpsrld		$25, \b, \t1
		vpor		\t0, \t1, \b
	.endm

	.macro RotDiagonal b, c, d
		vpshufd		$0b00111001, \b, \b
		vpshufd		$0b01001110, \c, \c
		vpshufd		$0b10010011, \d, \d
	.endm

	.macro RotStraight b, c, d
		vpshufd		$0b10010011, \b, \b
		vpshufd		$0b01001110, \c, \c
		vpshufd		$0b00111001, \d, \d
	.endm

	.macro DiagonalRound a, b, c, d, t0, t1
		RotDiagonal	\b, \c, \d
		StraightRound	\a, \b, \c, \d, \t0, \t1
		RotStraight	\b, \c, \d
	.endm

	.macro ChaCha20 a, b, c, d, t0, t1
	.rep 10
		StraightRound	\a, \b, \c, \d, \t0, \t1
		DiagonalRound	\a, \b, \c, \d, \t0, \t1
	.endr
	.endm

	.globl ChaCha20RandomBlocks
	.hidden ChaCha20RandomBlocks
	.type ChaCha20RandomBlocks, @function

ChaCha20RandomBlocks:
	.cfi_startproc
	endbr64
	// NSRandom guarantees that we are never called with a zero-length request. We are also guaranteed to operate
	// on aligned memory, courtesy of mmap(). Place original rows in %xmm4 to %xmm7.
	vmovdqa		0(%rdi), %xmm4
	vmovdqa		16(%rdi), %xmm5
	vmovdqa		32(%rdi), %xmm6
	vmovdqa		48(%rdi), %xmm7
	// Load a one into %xmm8 to increment the block counter. The VEX-encoded vmovd zeroes the upper lanes for us,
	// so we land on {1, 0, 0, 0} without a separate clear.
	mov		$1, %eax
	vmovd		%eax, %xmm8

vectorLoop:
	// Put the rows in %xmm0 to %xmm3 for processing.
	vmovdqa		%xmm4, %xmm0
	vmovdqa		%xmm5, %xmm1
	vmovdqa		%xmm6, %xmm2
	vmovdqa		%xmm7, %xmm3

	// Dance, dance, dance!
	ChaCha20	%xmm0, %xmm1, %xmm2, %xmm3, %xmm9, %xmm10

	// Add original rows.
	vpaddd		%xmm4, %xmm0, %xmm0
	vpaddd		%xmm5, %xmm1, %xmm1
	vpaddd		%xmm6, %xmm2, %xmm2
	vpaddd		%xmm7, %xmm3, %xmm3

	// Increment the block counter.
	vpaddd		%xmm8, %xmm7, %xmm7

	// Store these random bytes.
	vmovdqu		%xmm0, 0(%rsi)
	vmovdqu		%xmm1, 16(%rsi)
	vmovdqu		%xmm2, 32(%rsi)
	vmovdqu		%xmm3, 48(%rsi)

	// Increment our bytes pointer, decrement our desired block count, and see if we have any more.
	add		$64, %rsi
	dec		%rdx
	test		%rdx, %rdx
	jnz		vectorLoop

	// Otherwise, we are all done. Store the block counter back into the state.
	vmovd		%xmm7, 48(%rdi)
	vzeroupper
	ret
	.cfi_endproc

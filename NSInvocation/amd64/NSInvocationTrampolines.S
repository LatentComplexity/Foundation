
//
// amd64 trampolines for NSInvocation.
//
// NSInvocationCall() performs a forward call by loading registers, preparing the stack frame, calling the IMP, and
// capturing the return registers. NSInvocationForward() performs a "reverse call" (forwarding).
//
// NSInvocationForwardStret() performs a "reverse call" (forwarding) for a message returning a structure.
//

	.section .text

	.set FR_GP, 0
	.set FR_SSE, 48
	.set FR_STACK, 112
	.set FR_SBYTES, 120
	.set FR_FN, 128
	.set FR_RET, 136

	.balign 16, 0x90
	.globl NSInvocationCall
	.hidden NSInvocationCall
	.type NSInvocationCall, @function

NSInvocationCall:
	.cfi_startproc
	endbr64

	// Save %rbx. It will hold the frame across the call.
	push	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	mov	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	push	%rbx
	.cfi_offset %rbx, -24
	mov	%rdi, %rbx

	// Reserve the overflow block and align rsp to 16 bytes for the call.
	mov	FR_SBYTES(%rbx), %rax
	sub	%rax, %rsp
	and	$-16, %rsp

	// Copy the overflow block to [rsp, rsp+stackbytes).
	mov	FR_SBYTES(%rbx), %rcx
	test	%rcx, %rcx
	jz	1f
	mov	FR_STACK(%rbx), %rsi
	mov	%rsp, %rdi
	rep movsb
1:
	// Load the SSE argument registers (low 8 bytes of each is all the System V ABI requires).
	movsd	FR_SSE+0(%rbx), %xmm0
	movsd	FR_SSE+8(%rbx), %xmm1
	movsd	FR_SSE+16(%rbx), %xmm2
	movsd	FR_SSE+24(%rbx), %xmm3
	movsd	FR_SSE+32(%rbx), %xmm4
	movsd	FR_SSE+40(%rbx), %xmm5
	movsd	FR_SSE+48(%rbx), %xmm6
	movsd	FR_SSE+56(%rbx), %xmm7

	// Load the GP argument registers. r11 holds the call target.
	mov	FR_GP+8(%rbx), %rsi
	mov	FR_GP+16(%rbx), %rdx
	mov	FR_GP+24(%rbx), %rcx
	mov	FR_GP+32(%rbx), %r8
	mov	FR_GP+40(%rbx), %r9
	mov	FR_FN(%rbx), %r11
	mov	FR_GP+0(%rbx), %rdi
	call	*%r11

	// Capture the return registers.
	mov	%rax, FR_RET+0(%rbx)
	mov	%rdx, FR_RET+8(%rbx)
	movsd	%xmm0, FR_RET+16(%rbx)
	movsd	%xmm1, FR_RET+24(%rbx)

	// Discard overflow block and alignment slack.
	lea	-8(%rbp), %rsp
	pop	%rbx
	.cfi_restore %rbx
	pop	%rbp
	.cfi_def_cfa %rsp, 8
	ret
	.cfi_endproc
	.size NSInvocationCall, .-NSInvocationCall


	.set FW_GP,     0
	.set FW_SSE,    48
	.set FW_STACK,  112
	.set FW_RET,    120
	.set FW_RETSSE, 136

// The runtime tail-calls the IMP returned by __objc_msg_forward2() with the original message registers and stack
// intact. We save them into an NSForwardRegs on our own frame, hand it to the C handler, then load the return
// registers the handler wrote back. Incoming stack arguments start at rbp + 16.

	.macro FORWARD name, stret
	.balign 16, 0x90
	.globl \name
	.hidden \name
	.type \name, @function
\name:
	// Make space for the registers (152 bytes, rounded up to 160 for 16-byte alignment.)
	.cfi_startproc
	endbr64
	push	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	mov	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	sub	$160, %rsp

	// Save the incoming registers on our stack.
	mov	%rdi, FW_GP+0(%rsp)
	mov	%rsi, FW_GP+8(%rsp)
	mov	%rdx, FW_GP+16(%rsp)
	mov	%rcx, FW_GP+24(%rsp)
	mov	%r8, FW_GP+32(%rsp)
	mov	%r9, FW_GP+40(%rsp)
	movsd	%xmm0, FW_SSE+0(%rsp)
	movsd	%xmm1, FW_SSE+8(%rsp)
	movsd	%xmm2, FW_SSE+16(%rsp)
	movsd	%xmm3, FW_SSE+24(%rsp)
	movsd	%xmm4, FW_SSE+32(%rsp)
	movsd	%xmm5, FW_SSE+40(%rsp)
	movsd	%xmm6, FW_SSE+48(%rsp)
	movsd	%xmm7, FW_SSE+56(%rsp)

	// Get address of first incoming stack argument.
	lea	16(%rbp), %rax
	mov	%rax, FW_STACK(%rsp)

	// Pass stack address as holding incoming registers; to stret, or not to stret?
	mov	%rsp, %rdi
	mov	$\stret, %esi

	call	NSInvocationForwardHandler@PLT

	// Put back all return value-related registers.
	mov	FW_RET+0(%rsp), %rax
	mov	FW_RET+8(%rsp), %rdx
	movsd	FW_RETSSE+0(%rsp), %xmm0
	movsd	FW_RETSSE+8(%rsp), %xmm1

	// Put the stack back to where it was and restore %rbp.
	mov	%rbp, %rsp
	pop	%rbp
	.cfi_def_cfa %rsp, 8
	ret
	.cfi_endproc
	.size \name, .-\name
	.endm

	FORWARD NSInvocationForward, 0
	FORWARD NSInvocationForwardStret, 1

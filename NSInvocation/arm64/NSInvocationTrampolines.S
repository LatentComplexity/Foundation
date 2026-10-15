
//
// arm64 trampolines for NSInvocation.
//
// NSInvocationCall() performs a forward call by loading registers, preparing the stack frame, calling the IMP, and
// capturing the return registers. NSInvocationForward() performs a "reverse call" (forwarding).
//
// BTI landing pads are spelled as raw hints so we don't mess around with -march flags. The d registers are all that
// is loaded and stored from the SIMD bank: the permitted type set can never populate the upper 64 bits of a `v`
// register.
//

	.section .text

	.set FR_GP, 0
	.set FR_X8, 64
	.set FR_FP, 72
	.set FR_STACK, 136
	.set FR_SBYTES, 144
	.set FR_FN, 152
	.set FR_RET, 160

	.balign 16
	.globl NSInvocationCall
	.hidden NSInvocationCall
	.type NSInvocationCall, %function

NSInvocationCall:
	.cfi_startproc
	hint	#34	// bti c

	// Build a frame record. x19 holds the frame across the call.
	stp	x29, x30, [sp, #-32]!
	.cfi_def_cfa_offset 32
	.cfi_offset x29, -32
	.cfi_offset x30, -24
	mov	x29, sp
	.cfi_def_cfa_register x29
	str	x19, [sp, #16]
	.cfi_offset x19, -16
	mov	x19, x0

	// Reserve the overflow block. stackSize is always a multiple of 16, so sp stays aligned.
	ldr	x9, [x19, #FR_SBYTES]
	sub	sp, sp, x9

	// Copy the overflow block to [sp, sp+stackSize), eight bytes at a time, from the top down.
	cbz	x9, 1f
	ldr	x10, [x19, #FR_STACK]
	mov	x11, sp
0:
	sub	x9, x9, #8
	ldr	x12, [x10, x9]
	str	x12, [x11, x9]
	cbnz	x9, 0b
1:
	// Load the SIMD argument registers.
	ldp	d0, d1, [x19, #FR_FP]
	ldp	d2, d3, [x19, #FR_FP+16]
	ldp	d4, d5, [x19, #FR_FP+32]
	ldp	d6, d7, [x19, #FR_FP+48]

	// Load the indirect result location register and the GP argument registers. x17 holds the call target.
	ldr	x8, [x19, #FR_X8]
	ldr	x17, [x19, #FR_FN]
	ldp	x0, x1, [x19, #FR_GP]
	ldp	x2, x3, [x19, #FR_GP+16]
	ldp	x4, x5, [x19, #FR_GP+32]
	ldp	x6, x7, [x19, #FR_GP+48]
	blr	x17

	// Capture the return registers.
	stp	x0, x1, [x19, #FR_RET]
	stp	d0, d1, [x19, #FR_RET+16]
	stp	d2, d3, [x19, #FR_RET+32]

	// Discard the overflow block; restore x19 and the frame record.
	mov	sp, x29
	ldr	x19, [sp, #16]
	.cfi_restore x19
	ldp	x29, x30, [sp], #32
	.cfi_restore x29
	.cfi_restore x30
	.cfi_def_cfa sp, 0
	ret
	.cfi_endproc
	.size NSInvocationCall, .-NSInvocationCall


	.set FW_GP, 0
	.set FW_X8, 64
	.set FW_FP, 72
	.set FW_STACK, 136
	.set FW_RET, 144

// The runtime tail-calls the IMP returned by __objc_msg_forward2() with the original message registers and stack
// intact. We save the registers into an NSInvocationForwardingRegisters on our own frame, hand it to the C handler,
// then load the return registers the handler wrote back. The record occupies 192 bytes above a 16-byte frame record.
// The landing pad is `bti jc` since the runtime arrives via br x9, which a `bti c` pad would reject.

	.balign 16
	.globl NSInvocationForward
	.hidden NSInvocationForward
	.type NSInvocationForward, %function

NSInvocationForward:
	.cfi_startproc
	hint	#38	// bti jc

	// Build a frame record, with the register record living above it at sp+16.
	stp	x29, x30, [sp, #-208]!
	.cfi_def_cfa_offset 208
	.cfi_offset x29, -208
	.cfi_offset x30, -200
	mov	x29, sp
	.cfi_def_cfa_register x29

	// Save the incoming argument registers into the record.
	stp	x0, x1, [sp, #16+FW_GP]
	stp	x2, x3, [sp, #16+FW_GP+16]
	stp	x4, x5, [sp, #16+FW_GP+32]
	stp	x6, x7, [sp, #16+FW_GP+48]
	str	x8, [sp, #16+FW_X8]
	stp	d0, d1, [sp, #16+FW_FP]
	stp	d2, d3, [sp, #16+FW_FP+16]
	stp	d4, d5, [sp, #16+FW_FP+32]
	stp	d6, d7, [sp, #16+FW_FP+48]

	// Get the address of the first incoming stack argument (our entry sp).
	add	x9, x29, #208
	str	x9, [sp, #16+FW_STACK]

	// Hand the record to the C handler.
	add	x0, sp, #16
	bl	NSInvocationForwardHandler

	// Put back all return value-related registers.
	ldp	x0, x1, [sp, #16+FW_RET]
	ldp	d0, d1, [sp, #16+FW_RET+16]
	ldp	d2, d3, [sp, #16+FW_RET+32]

	// Restore the frame record.
	ldp	x29, x30, [sp], #208
	.cfi_restore x29
	.cfi_restore x30
	.cfi_def_cfa sp, 0
	ret
	.cfi_endproc
	.size NSInvocationForward, .-NSInvocationForward

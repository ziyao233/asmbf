/*
 *	asmbf
 *	A brainfuck interpreter written in pure x86-64 assembly (AT&T style)
 *	Date:2022.12.16
 *	By MIT License.
 *	Copyright (c) 2022 Ziyao.
 */

#define BRAINFUCK_MEM	(1024 * 1024 )

#define O_RDONLY	00
#define SEEK_SET	0
#define SEEK_END	2
#define PROT_READ	0x1
#define PROT_WRITE	0x2
#define MAP_SHARED	0x01
#define MAP_ANONYMOUS	0x20

	.global		_start

	.text
_start:
/*
 *	Open the source file and load it into memory
 */
	movq		(%rsp),		%rax
	decq		%rax
	jnz		loadFile
	/*	argc == 1	*/
	movq		$noEnoughArg,	%rsi
	callq		print
	movq		$-1,		%rdi		// exit
	jmp		exitFinal

loadFile:
	/*	Open	*/
	xorq		%r12,		%r12		// %r12 is 0
	movq		16(%rsp),	%rdi
	movq		$O_RDONLY,	%rsi
	xorq		%rdx,		%rdx
	movq		$2,		%rax		// sys_open
	syscall
	cmpq		%r12,		%rax
	jl		errorLoadFile
	movq		%rax,		%r13		// %r13 holding fd

	/*	Get size	*/
	movq		%rax,		%rdi
	xorq		%rsi,		%rsi
	movq		$SEEK_END,	%rdx		// SEEK_END
	movq		$8,		%rax		// sys_lseek
	syscall
	cmpq		%r12,		%rax
	jl		errorLoadFile
	movq		%rax,		%r14		// %r14 holding size

	movq		%rax,		%rcx
	movq		$8,		%rax
	movq		$SEEK_SET,	%rdx		// SEEK_SET
	syscall

	/*	Do mapping	*/
	xorq		%rdi,		%rdi
	movq		%r14,		%rsi
	addq		$BRAINFUCK_MEM,	%rsi		// Allocate only once
	incq		%rsi				// The '\0'
	movq		$(PROT_READ | PROT_WRITE),%rdx
	movq		$(MAP_ANONYMOUS | MAP_SHARED),%r10
	xorq		%r9,		%r9
	movq		%r9,		%r8
	decq		%r8
	movq		$9,		%rax		// sys_mmap
	syscall
	decq		%r12				// %r12 is -1 now
	cmpq		%r12,		%rax
	je		errorLoadFile
	movq		%rax,		%r15

	/*	Load into memory	*/
	movq		%r13,		%rdi
	movq		%rax,		%rsi
	movq		%r14,		%rdx
	movq		$0,		%rax
	syscall
	cmpq		%rax,		%r14
	jne		errorLoadFile
	movb		%al,		1(%r15,%r14)	// %rax is 0

	/*	Close file		*/
	movq		$3,		%rax
	syscall

	jmp		initInterpreter

errorLoadFile:
	movq		$cannotLoadFile,%rsi
	callq		print
	movq		$-1,		%rdi
	jmp		exitFinal

/*
 *	%rbx		Base address of the look-up table for instructions
 *	%r12		PC
 *	%r13		Data Pointer
 *	Loop nesting is recorded in the stack
 */
initInterpreter:
	/*	Clear the data section	*/
	leaq		1(%r15,%r14),	%rdi
	movq		%rdi,		%r13
	xorq		%rax,		%rax
	movq		$BRAINFUCK_MEM,	%rcx
repnz	stosb

	/*	Set registers	*/
	movq		%r15,		%r12		// PC
	movq		$instTable,	%rbx

.interpreterLoop:
	xorq		%rax,		%rax
	movb		(%r12),		%al
	incq		%r12
	jmp		*(%rbx,%rax,8)
instPrev:
	decq		%r13
	jmp		.interpreterLoop
instNext:
	incq		%r13
	jmp		.interpreterLoop
instWrite:
	movq		%r13,		%rsi
	movq		$1,		%rax
	movq		%rax,		%rdi
	movq		%rax,		%rdx
	syscall
	jmp		.interpreterLoop
instRead:
	movq		%r13,		%rsi
	movq		$0,		%rax
	movq		%rax,		%rdi
	movq		$1,		%rdx
	syscall
	jmp		.interpreterLoop
instInc:
	movb		(%r13),		%al
	incb		%al
	movb		%al,		(%r13)
	jmp		.interpreterLoop
instDec:
	movb		(%r13),		%al
	decb		%al
	movb		%al,		(%r13)
	jmp		.interpreterLoop
instLoopBegin:
	xorq		%rax,		%rax
	cmpb		(%r13),		%al
	jne		.saveContext

	/*	Get to the end	*/
	movq		$1,		%rcx
	movq		%rax,		%rdx
.findNext:
	movb		(%r12),		%al
	cmpb		$'[',		%al
	je		.increaseNest
	cmpb		$']',		%al
	je		.decreaseNest
	jmp		.nextLoop
.increaseNest:
	incq		%rcx
	jmp		.nextLoop
.decreaseNest:
	decq		%rcx
	jmp		.nextLoop
.nextLoop:
	incq		%r12
	xorq		%rax,		%rax
	cmpq		%rcx,		%rdx
	jne		.findNext

	jmp		.interpreterLoop

.saveContext:
	pushq		%r12
	jmp		.interpreterLoop
instLoopEnd:
	xorq		%rax,		%rax
	cmpb		(%r13),		%al
	je		.jumpOutOfLoop
	movq		(%rsp),		%r12
	jmp		.interpreterLoop
.jumpOutOfLoop:
	addq		$8,		%rsp
	jmp		.interpreterLoop
instEnd:

/*
 *	Exit the program
 */
exit:
	movq		$0,		%rdi

	/*	Exit gently	*/
	movq		%r15,		%rdi
	movq		$11,		%rax
	syscall
exitFinal:
	movq		$60,		%rax
	syscall

/*
 *	Print to the stdout (assuming its fd is 1)
 *	Input:
 *		%rsi		Address of the message
 */
print:
	pushq		%rcx
	pushq		%rdx
	callq		strlen

	movq		$1,		%rdx
	callq		write

	popq		%rdx
	popq		%rcx
	ret

/*
 *	Write data to a file
 *	Input:
 *		%rsi		Address of the buffer
 *		%rcx		Size
 *		%rdx		File descriptor
 *	Output:
 *		%rcx		Remaining size
 */
write:
	pushq		%rax
	pushq		%rdi
	movq		%rdx,		%rdi
	movq		%rcx,		%rdx
	movq		$1,		%rax
	syscall
	sub		%rax,		%rcx
	popq		%rdi
	popq		%rax
	ret

/*
 *	Get the length of a string
 *	Input:
 *		%rsi		Address of the string
 *	output:
 *		%rcx		Length
 *	Kept:
 *		%rsi
 */
strlen:
	pushq		%rax
	pushq		%rdi
	movq		%rsi,		%rdi
	xor		%rax,		%rax
	xor		%rcx,		%rcx
	not		%rcx
repnz	scasb
	neg		%rcx
	popq		%rdi
	popq		%rax
	dec		%rcx
	ret

	.data

noEnoughArg:	.asciz		"Need source file path\n"
cannotLoadFile:	.asciz		"Cannot load source file\n"

instTable:
	.quad		instEnd
.rept 42
	.quad		.interpreterLoop
.endr
	.quad		instInc
	.quad		instRead
	.quad		instDec
	.quad		instWrite
.rept 13
	.quad		.interpreterLoop
.endr
	.quad		instPrev
	.quad		.interpreterLoop
	.quad		instNext
.rept 28
	.quad		.interpreterLoop
.endr
	.quad		instLoopBegin
	.quad		.interpreterLoop
	.quad		instLoopEnd
.rept	162
	.quad		.interpreterLoop
.endr

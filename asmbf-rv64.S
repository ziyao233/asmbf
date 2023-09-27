/*
 *	asmbf-rv64
 *	The rv64 port of asmbf:
 *		a brainfuck interpreter written in pure rv64 assembly.
 *	Date: 2023.09.27
 *	By MIT License.
 *	Copyright (c) 2023 Yao Zi.
 */

#define BRAINFUCK_MEM		(1024 * 1024)
#define O_RDONLY		00
#define SEEK_SET		0
#define SEEK_END		2
#define PROT_READ		0x1
#define PROT_WRITE		0x2
#define MAP_SHARED		0x01
#define MAP_ANONYMOUS		0x20
#define FILENO_STDIN		0
#define FILENO_STDOUT		1
#define AT_FDCWD		-100

#define sys_exit		93
#define sys_read		63
#define sys_write		64
#define sys_close		57
#define sys_openat		56
#define sys_lseek		62
#define sys_mmap		222

	.global			_start
	.text
_start:
/*
 *	Open the source file and load it into memory
 */
	ld		a0,		0(sp)
	addi		a0,		a0,		-1
	bnez		a0,		loadFile
	/*	argc == 1	*/
	la		a0,		noEnoughArg
	call		print
	li		a0,		-1
	j		exitFinal

loadFile:
	li		a0,		AT_FDCWD
	ld		a1,		16(sp)
	li		a2,		O_RDONLY
	mv		a3,		zero
	li		a7,		sys_openat
	ecall
	blt		a0,		zero,		errorLoadFile

	mv		s6,		a0		// a0, s6: fd

	/*	Get size	*/
	mv		a1,		zero
	li		a2,		SEEK_END
	li		a7,		sys_lseek
	ecall
	blt		a0,		zero,		errorLoadFile
	mv		s5,		a0		// s5, a0 hold size

	mv		a0,		s6
	mv		a1,		zero
	li		a2,		SEEK_SET
	li		a7,		sys_lseek
	ecall						// Rewind
	blt		a0,		zero,		errorLoadFile

	/*	Do mapping	*/
	mv		a0,		zero
	li		a1,		BRAINFUCK_MEM
	add		a1,		a1,		s5
	addi		a1,		a1,		1
	li		a2,		(PROT_READ | PROT_WRITE)
	li		a3,		(MAP_ANONYMOUS | MAP_SHARED)
	mv		a4,		zero
	li		s0,		-1
	mv		a7,		s0
	li		a7,		sys_mmap
	ecall
	beq		a0,		s0,		errorLoadFile
	mv		s0,		a0

	/*	Load the file into memory	*/
	mv		a0,		s6
	mv		a1,		s0
	mv		a2,		s5
	li		a7,		sys_read
	ecall
	bne		a0,		s5,		errorLoadFile
	add		t0,		s0,		s5
	sb		zero,		1(t0)

	mv		a0,		s6
	li		a7,		sys_close
	ecall

	j		initInterpreter

errorLoadFile:
	la		a0,		cannotLoadFile
	call		print
	li		a0,		-1
	j		exitFinal

initInterpreter:
	/*	Clear the data section	*/
	add		t0,		s0,		s5
	mv		s2,		t0
	li		t1,		BRAINFUCK_MEM
.clearDataSection:
	sb		zero,		1(t0)
	addi		t1,		t1,		-1
	bnez		t1,		.clearDataSection

	/*	s1: pc		s2: data	s3: lookup table 	*/
	mv		s1,		s0
	addi		s2,		s2,		1
	la		s3,		instTable

.interpreterLoop:
	mv		t0,		zero
	lb		t0,		0(s1)
	slli		t0,		t0,		3
	add		t0,		t0,		s3
	ld		t0,		0(t0)
	addi		s1,		s1,		1
	jalr		zero,		t0

instPrev:
	addi		s2,		s2,		-1
	j		.interpreterLoop
instNext:
	addi		s2,		s2,		1
	j		.interpreterLoop
instWrite:
	li		a0,		FILENO_STDOUT
	mv		a1,		s2
	li		a2,		1
	li		a7,		sys_write
	ecall
	j		.interpreterLoop
instRead:
	li		a0,		FILENO_STDIN
	mv		a1,		s2
	li		a2,		1
	li		a7,		sys_read
	ecall
	j		.interpreterLoop
instInc:
	lb		t0,		0(s2)
	addi		t0,		t0,		1
	sb		t0,		0(s2)
	j		.interpreterLoop
instDec:
	lb		t0,		0(s2)
	addi		t0,		t0,		-1
	sb		t0,		0(s2)
	j		.interpreterLoop
instLoopBegin:
	lb		t0,		0(s2)
	bnez		t0,		.saveContext

	li		t1,		1		// t1 is a counter
.findNext:
	lb		t0,		0(s1)
	li		t2,		'['
	beq		t0,		t2,		.increaseNest
	li		t2,		'];
	beq		t0,		t2,		.decreaseNest
	j		.nextLoop
.increaseNest:
	addi		t1,		t1,		1
	j		.nextLoop
.decreaseNest:
	addi		t1,		t1,		-1
	j		.nextLoop
.nextLoop:
	addi		s1,		s1,		1
	bnez		t1,		.findNext

	j		.interpreterLoop

.saveContext:
	addi		sp,		sp,		-8
	sd		s1,		0(sp)
	j		.interpreterLoop

instLoopEnd:
	lb		t0,		0(s2)
	beqz		t0,		.jumpOutOfLoop
	ld		s1,		0(sp)
	j		.interpreterLoop
.jumpOutOfLoop:
	addi		sp,		sp,		8
	j		.interpreterLoop
instEnd:

exitFinal:
	li		a7,		sys_exit
	ecall

print:
	mv		a2,		zero
	mv		t2,		a0
.repeatLen:
	lb		t0,		(t2)
	beqz		t0,		.doWrite
	addi		t2,		t2,		1
	addi		a2,		a2,		1
	j		.repeatLen

	/* a0 holds the address of the string, and t2 holds the its length */
.doWrite:
	mv		a1,		a0
	li		a0,		FILENO_STDOUT
	li		a7,		sys_write
	ecall

	ret

	.data
noEnoughArg:	.asciz	"need file path\n"
cannotLoadFile:	.asciz	"cannot load file\n"

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
.rept   162
	.quad		.interpreterLoop
.endr

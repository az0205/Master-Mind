@ This ARM Assembler code should implement a matching function, for use in the MasterMind program, as
@ described in the CW2 specification. It should produce as output 2 numbers, the first for the
@ exact matches (peg of right colour and in right position) and approximate matches (peg of right
@ color but not in right position). Make sure to count each peg just once!
	
@ Example (first sequence is secret, second sequence is guess):
@ 1 2 1
@ 3 1 3 ==> 0 1
@ You can return the result as a pointer to two numbers, or two values
@ encoded within one number
@
@ -----------------------------------------------------------------------------

.text
@ this is the matching fct that should be called from the C part of the CW	
.global         matches
@ use the name `main` here, for standalone testing of the assembler code
@ when integrating this code into `master-mind.c`, choose a different name
@ otw there will be a clash with the main function in the C code
.global         mainARM
mainARM: 
    push {r2,r3, r6, r7, r8, r9, r10, r11, r12, lr}

    ldr r4, =usedExact
    ldr r5, =usedApprox

    mov   r6, #0
    str   r6, [r4]                @ usedExact[0] = 0
    str   r6, [r4, #4]            @ usedExact[1] = 0
    str   r6, [r4, #8]            @ usedExact[2] = 0
    str   r6, [r5]                @ usedApprox[0] = 0
    str   r6, [r5, #4]            @ usedApprox[1] = 0
    str   r6, [r5, #8]            @ usedApprox[2] = 0
    
    pop {r2, r3, r6, r7, r8, r9, r10, r11, r12, lr}

    bx lr


exit:	MOV	 R0, R4		@ load result to output register
	    MOV 	 R7, #1		@ load system call code
	    SWI 	 0		@ return this value

@ -----------------------------------------------------------------------------
@ sub-routines

    


matches:
	push {r2,r3, r6, r7, r8, r9, r10, r11, r12, lr}             @ Save registers r4..r13 and lr
	
    bl mainARM

    mov   r2, #0                  @ r2 = exact count
    mov   r7, #0                  @ r7 = i = 0
exact_loop:
    cmp   r7, #LEN
    bge   exact_loop_end          @ if i >= LEN, exit loop
    mov   r10, r7, LSL #2         @ r10 = i * 4 (byte offset)
    ldr   r11, [r0, r10]          @ r11 = secret[i]
    ldr   r12, [r1, r10]          @ r12 = guess[i]
    cmp   r11, r12
    bne   exact_skip            @ if not equal, skip marking
    add   r2, r2, #1              @ exact count++
    add   r12, r4, r10            @ r13 = address of usedExact[i] (r4 holds usedExact base)
    mov   r11, #1
    str   r11, [r12]             @ mark usedExact[i] = 1
exact_skip:
    add   r7, r7, #1              @ i++
    b     exact_loop
exact_loop_end:

    @ Second Loop: Count approximate matches.
    @ For each secret element (outer index i) that was not an exact match,
    @ search the guess array for an unused match.
    @ r9 will accumulate the approx count.
    @ Outer loop index (i) is in r7; inner loop index (j) is in r12.
    mov   r3, #0                  @ r3 = approx count
    mov   r7, #0                  @ r7 = outer loop index i = 0
outer_loop:
    cmp   r7, #LEN
    bge   outer_loop_end          @ if i >= LEN, exit outer loop
    mov   r10, r7, LSL #2         @ r10 = i * 4
    ldr   r11, [r4, r10]          @ r11 = usedExact[i] from usedExact (r4)
    cmp   r11, #0
    bne   outer_loop_skip         @ if secret[i] was an exact match, skip inner loop

    mov   r12, #0                 @ r12 = inner loop index j = 0
inner_loop:
    cmp   r12, #LEN
    bge   outer_loop_skip         @ if j >= LEN, no candidate found; go next i
    mov   r10, r12, LSL #2         @ r10 = j * 4
    ldr   r11, [r5, r10]          @ r11 = usedApprox[j] from usedApprox (r5)
    cmp   r11, #0
    bne   inner_loop_next         @ if guess[j] is already used, try next j
    ldr   r11, [r4, r10]          @ check usedExact[j] for guess element j
    cmp   r11, #0
    bne   inner_loop_next         @ if guess[j] was used as exact, skip j

    @ Compare secret[i] with guess[j]:
    mov   r10, r7, LSL #2         @ r10 = offset for secret[i] (outer index)
    ldr   r11, [r0, r10]          @ r11 = secret[i]
    mov   r10, r12, LSL #2        @ r10 = offset for guess[j] (inner index)
    ldr   r10, [r1, r10]          @ r10 = guess[j]
    cmp   r11, r10
    bne   inner_loop_next         @ if not equal, try next j

    add   r3, r3, #1              @ increment approx count
    mov   r10, r12, LSL #2        @ r10 = j * 4
    add   r10, r5, r10            @ r10 = address of usedApprox[j]
    mov   r11, #1
    str   r11, [r10]             @ mark usedApprox[j] = 1
    b     outer_loop_skip         @ break inner loop after a match
inner_loop_next:
    add   r12, r12, #1            @ j++
    b     inner_loop

outer_loop_skip:
    add   r7, r7, #1              @ i++
    b     outer_loop
outer_loop_end:

    @ Store results into global result array and return its address.
    @ result[0] = exact count, result[1] = approx count.
    ldr   r10, =result
    str   r2, [r10]
    str   r3, [r10, #4]
    mov   r0, r10              @ return pointer to result in r0

    pop {r2, r3, r6, r7, r8, r9, r10, r11, r12, lr}         @ Restore registers and lr
    bx    lr
    
    
    @ show the sequence in R0, use a call to printf in libc to do the printing, a useful function when debugging 
showseq: 			@ Input: R0 = pointer to a sequence of 3 int values to show
	@ COMPLETE THE CODE HERE (OPTIONAL)
	
	
@ =============================================================================

.data
usedExact:  .word 0, 0, 0     @ Global array for exact-match flags
usedApprox: .word 0, 0, 0     @ Global array for approximate-match flags
result: .word 0, 0

@ constants about the basic setup of the game: length of sequence and number of colors	
.equ LEN, 3

@ a format string for printf that can be used in showseq
f4str: .asciz "Seq:    %d %d %d\n"

@ a memory location, initialised as 0, you may need this in the matching fct
n: .word 0x00
	
@ INPUT DATA for the matching function
.align 4
secret: .word 1 
	.word 2 
	.word 1 

.align 4
guess:	.word 3 
	.word 1 
	.word 3 

@ Not strictly necessary, but can be used to test the result	
@ Expect Answer: 0 1
.align 4
expect: .byte 0
	.byte 1

.align 4
secret1: .word 1 
	 .word 2 
	 .word 3 

.align 4
guess1:	.word 1 
	.word 1 
	.word 2 

@ Not strictly necessary, but can be used to test the result	
@ Expect Answer: 1 1
.align 4
expect1: .byte 1
	 .byte 1

.align 4
secret2: .word 2 
	 .word 3
	 .word 2 

.align 4
guess2:	.word 3 
	.word 3 
	.word 1 

@ Not strictly necessary, but can be used to test the result	
@ Expect Answer: 1 0
.align 4
expect2: .byte 1
	 .byte 0
	 
.section .note.GNU-stack, ""    @ Not sure what this does, but without this-prints error.

; Addresses for I/O
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090

; The stack is at the top of memory
.NAME	StkTop=65536

; -----------------------------------------------------------------
; Processor Initialization
	.ORG 0x100
	XOR		Zero,Zero,Zero						; Put a zero in the Zero register
	LW		SP,StackTopVal(Zero)			; Load the initial stack-top value into the SP
	SW		Zero,LEDR(Zero)						; Turn off LEDR
	ADDI		Zero,A0,0xFFFFFF
	SW		A0,HEX(Zero)

MainLoop:
	LW		T0,HEX(Zero)
	SUBI		T0,T0,1
	SW		T0,HEX(Zero)
	BNE		Zero,T0,MainLoop
	LW		T1,LEDR(Zero)
	XORI		T1,T1,0x3FF
	SW		T1,LEDR(Zero)
	BR		MainLoop
	

; -----------------------------------------------------------------
StackTopVal:
.WORD StkTop
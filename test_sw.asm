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
	SW		Zero,HEX(Zero)
	ADDI		Zero,A0,SW
Poll:
	LW		T0,4(A0)
	ANDI		T0,T0,0x1
	BEQ		T0,Zero,Poll
	LW		T0,SW(Zero)
	SW		T0,LEDR(Zero)
	LW		T0,HEX(Zero)
	ADDI		T0,T0,1
	SW		T0,HEX(Zero)
	BR 		Poll

; -----------------------------------------------------------------
StackTopVal:
.WORD StkTop
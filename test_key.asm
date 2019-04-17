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

MainLoop:
	ADDI		Zero,A0,KEY
Poll:
	LW		T0,4(A0)
	ANDI		T0,T0,0x1
	BEQ		T0,Zero,Poll

	LW		T0,KEY(Zero)
	LW		T1,LEDR(Zero)
	ORI		T0,T0,0x3F0
	XOR		T1,T1,T0
	SW		T1,LEDR(Zero)
	BR		MainLoop

; -----------------------------------------------------------------
StackTopVal:
.WORD StkTop
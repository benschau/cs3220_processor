; Addresses for I/O
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090
.NAME   TIMER= 0xFFFFF100
.NAME   TLIM= 0xFFFFF104
.NAME   TCTL= 0xFFFFF108

; The stack is at the top of memory
.NAME	StkTop=65536

; -----------------------------------------------------------------
; Processor Initialization
	.ORG 0x100
	XOR		Zero,Zero,Zero						; Put a zero in the Zero register
	LW		SP,StackTopVal(Zero)			; Load the initial stack-top value into the SP
	SW		Zero,LEDR(Zero)						; Turn off LEDR
	SW		Zero,HEX(Zero)
	
	ADDI		Zero,A0,500
	SW		A0,TLIM(Zero)
	WSR		IDN,Zero

MainLoop:
	LW		T0,TCTL(Zero)
	ANDI		T0,T1,1
	BEQ		Zero,T1,MainLoop
	ANDI		T0,T0,0xFFFFFFFE
	SW		T0,TCTL(Zero)
	RSR		T0,IDN
	ADDI		T0,T0,1
	WSR		IDN,T0
	RSR		T0,IDN
	SW		T0,HEX(Zero)
	BR		MainLoop

; -----------------------------------------------------------------
StackTopVal:
.WORD StkTop
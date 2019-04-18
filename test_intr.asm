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
	LW		SSP,StackTopVal(Zero)			; Load the initial stack-top value into the SSP
	SW		Zero,LEDR(Zero)						; Turn off LEDR
	SW		Zero,HEX(Zero)
	
	ADDI		Zero,T0,0x1000
	WSR		IHA,T0	

	ADDI		Zero,T0,0x10
	SW		T0,TCTL(Zero)
	ADDI		Zero,A0,500
	SW		A0,TLIM(Zero)

	ADDI		Zero,A1,12

	ADDI		Zero,T0,0x01
	WSR		PCS,T0

	ADDI		Zero,T0,0xFFF
	LSHF		T0,T0,A1
	ADDI		T0,T0,0xFFF
MainLoop:
	SUBI		T0,T0,1
	BNE		T0,Zero,MainLoop
	LW		T1,LEDR(Zero)
	NOT		T1,T1
	SW		T1,LEDR(Zero)
	ADDI		Zero,T0,0xFFF
	LSHF		T0,T0,A1
	ADDI		T0,T0,0xFFF
	BR		MainLoop

;Interrupt Handler
	.ORG 0x1000
	SUBI		SSP,SSP,4
	SW		T0,0(SSP)
	SUBI		SSP,SSP,4
	SW		T1,0(SSP)
	RSR		T0,IDN
	LW		T1,HEX(Zero)
	ADD		T1,T1,T0
	SW		T1,HEX(Zero)
	LW		T0,TCTL(Zero)
	ANDI		T0,T0,0xFFFFFFFE
	SW		T0,TCTL(Zero)
	LW		T1,0(SSP)
	ADDI		SSP,SSP,4
	LW		T0,0(SSP)
	ADDI		SSP,SSP,4
	RETI
	

; -----------------------------------------------------------------
StackTopVal:
.WORD StkTop
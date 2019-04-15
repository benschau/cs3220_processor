; Addresses for I/O
.NAME	HEX=  0xFFFFF000
.NAME	LEDR= 0xFFFFF020
.NAME	KEY=  0xFFFFF080
.NAME	SW=   0xFFFFF090

; The stack is at the top of memory
.NAME	StkTop=65536

; -----------------------------------------------------------------
; Processor Initialization
	.ORG 0x100
	XOR		Zero,Zero,Zero						; Put a zero in the Zero register
	LW		SP,StackTopVal(Zero)			    ; Load the initial stack-top value into the SP
	SW      Zero,LEDR(Zero)						; Turn off LEDR

    ; TODO: x-mas logic


; -----------------------------------------------------------------
; Interrupt Handler (BFIH)
    .ORG 0xFFFF0000
    IntHandler:
    ; save general purpose registers to the (system) stack
    ; TODO: which registers to save? 
    ADDI SSP,SSP,-8
    SW A0,0(SSP)
    SW A1,4(SSP)

    RSR     A0,IDN ; Get cause of Interrupt

    ; Decide what to do based on A0
    ; We'll do this on a case by case basis so we don't have an interrupt vector table.
    ADDI    A1,Zero,1
    BEQ     A0,A1,Timer         ; timer-id = 1
    ADDI    A1,A1,1
    BEQ     A0,A1,Key           ; key-id = 2
    ADDI    A1,A1,1             
    BEQ     A0,A1,Switch        ; sw-id = 3
    ADDI    A1,A1,1             

    ; TODO - are interrupt handlers for LEDR/HEX necessary?     

    ; Timer Handler
    Timer:
        ; TODO - fill out

        BR      IntHandlerCleanup

    ; Key Handler
    Key:
        ; TODO - fill out

        BR      IntHandlerCleanup

    ; Switch Handler
    Switch:
        ; TODO - fill out

        BR      IntHandlerCleanup

    IntHandlerCleanUp: 
        ; Restore general purpose registers to the stack
        ; TODO: if you change the top part, gotta change this part.
        LW      A0,0(SSP)
        LW      A1,4(SSP)
        ADDI    SSP,SSP,8

        ; Return, enable interrupts
        RETI
    

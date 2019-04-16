; Addresses for I/O
.NAME	HEX=  0xFFFFF000
.NAME	LEDR= 0xFFFFF020
.NAME	KEY=  0xFFFFF080
.NAME	SW=   0xFFFFF090

.NAME   TIMER=0xFFFFF100
.NAME   TLIM=0xFFFFF104

; The stack is at the top of memory
.NAME	StkTop=65536

; LED states
.NAME   UpperHalf=0x3E0         ; 11111 00000
.NAME   LowerHalf=0x01F         ; 00000 11111

; State machine counter- we'll store a 0 here and count up to 17 in the 
; timer interrupt handler.
.NAME	Counter=0x1000      

; Store current state speed value (for hex display)
.NAME   StateSpeed=0x1060

; Default blink speed & increment units
.NAME   DefBlinkSpeed=0x17D7840    ; 25000000
.NAME   DefIncrementVal=0xBEBC20   ; 12500000 

; Maximum/Minimum blink speed 
.NAME   MinBlinkSpeed=0xBEBC20     ; 12500000
.NAME   MaxBlinkSpeed=0x5F5E100    ; 100000000

; -----------------------------------------------------------------
; Processor Initialization
.ORG 0x100
	XOR		 Zero,Zero,Zero						; Put a zero in the Zero register
	LW		 SP,StackTopVal(Zero)			    ; Load the initial stack-top value into the SP
	SW       Zero,LEDR(Zero)						; Turn off LEDR

    ; Setup speed display
    ADDI    Zero,T0,StateSpeed                  ; Default speed state is at 4.
                                                ; We incr/decr based on each key.
                                                ; The digit we use to display is based on whichever switch is on (the first from the right)
    ADDI    Zero,T1,4
    SW      T1,0(T0)

    ; Initialize state machine counter.
    ADDI 	Zero,T0,Counter
    SW		Zero,0(T0)

    ; Initialize our counter using the new Timer module; we count down from A0 (BlinkSpeed) and reset each time.
    ADDI    Zero,A0,DefBlinkSpeed
    SW      A0,TLIM(Zero)                    ; Store BlinkSpeed at TLIM (0xFFFFF104)

    Forever:
         JMP     Forever(Zero)                ; The BFIH handles checking current blinking state speed, 
                                                 ; changing the LEDR location.
   
; -----------------------------------------------------------------
; Interrupt Handler (BFIH)
.ORG 0xFFFF0000
    IntHandler:
    ; save general purpose registers to the (system) stack
    ; TODO: which registers to save? 
    ADDI SSP,SSP,-16
    SW A0,0(SSP)
    SW A1,4(SSP)
    SW A2,8(SSP)
    SW A3,12(SSP)

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
        ; show halves of the LEDR based on counter.
        ADDI    Zero,A1,Counter
        LW      A0,0(A1)

        ; Check if counter is 18 or above:
        ADDI    Zero,A2,17
        BGT     A0,A2,ResetCounter      ; Check if current counter > 17
        BR      StateMachine

        ResetCounter:
            ADDI    Zero,A2,0           ; A2 <= 0
            ADDI    Zero,A0,Counter     ; A0 <= Counter 
            SW      A2,0(A0)            ; Counter <= 0
            ADDI    Zero,A1,0           ; A1 (Former counter contents) <= 0

        StateMachine:
            ADDI    Zero,A2,Zero
            BEQ     A1,A2,State0
            ADDI    Zero,A2,2
            BEQ     A1,A2,State2
            ADDI    Zero,A2,4
            BEQ     A1,A2,State4
            ADDI    Zero,A2,6
            BEQ     A1,A2,State6
            ADDI    Zero,A2,8
            BEQ     A1,A2,State8
            ADDI    Zero,A2,10
            BEQ     A1,A2,State10
            ADDI    Zero,A2,12
            BEQ     A1,A2,State12
            ADDI    Zero,A2,13
            BEQ     A1,A2,State13
            ADDI    Zero,A2,14
            BEQ     A1,A2,State14
            ADDI    Zero,A2,15
            BEQ     A1,A2,State15
            ADDI    Zero,A2,16
            BEQ     A1,A2,State16
            ADDI    Zero,A2,17
            BEQ     A1,A2,State17

            ; A state in which no LEDs are done.
            BR      EmptyState

            State0:
            State2:
            State4:
            State12:
            State14:
            State16:
                ADDI    Zero,A1,UpperHalf
                SW      A1,LEDR(Zero)
                BR      TimerCleanup

            State6:
            State8:
            State10:
            State13:
            State15:
            State17:
                ADDI    Zero,A1,LowerHalf
                SW      A1,LEDR(Zero)
                BR      TimerCleanup

            EmptyState:
                SW      Zero,LEDR(Zero)
                BR      TimerCleanup

        TimerCleanup:
            ; Increment the counter by one, re-store in the same place.
            ADDI    A0,A0,1
            ADDI    Zero,A1,Counter
            SW      A0,0(A1)

            BR IntHandlerCleanup

    ; Key Handler
    Key:
        ; TODO: Do I need to check KEYCTRL here first for the ready bit?

        ADDI    Zero,A2,1

        LW      A0,KEY(Zero)
        ANDI    A0,A1,1                         ; Check Key[0]
        BEQ     A1,A2,IncrSpeed                 ; If Key[0] == 1, increase blink speed.

        ANDI    A0,A1,2                         ; Check Key[2]
        ADDI    Zero,A2,2
        BEQ     A1,A2,DecrSpeed                 ; If Key[1] == 1, increase blink speed.

        IncrSpeed:
            ADDI    Zero,A1,DefIncrementVal
            LW      A0,TLIM(Zero)

            ADD     A2,A0,A1                    ; A2 <= TLIM/BlinkSpeed + DefIncrementVal
            ADDI    Zero,A1,MaxBlinkSpeed
            BGT     A2,A1,IntHandlerCleanup 

            SW      A2,TLIM(Zero)               ; If it's not past the max, store it.
    
            ADDI    Zero,A1,StateSpeed          
            LW      A2,0(A1)                    ; A2 <= StateSpeed contents 
            ADDI    A2,A2,1                     ; A2 <= A2 + 1     
            SW      A2,0(A1)                    ; Update the StateSpeed (for the HEX display)

            BR      IntHandlerCleanup
            
        DecrSpeed:
            ADDI    Zero,A1,DefIncrementVal
            LW      A0,TLIM(Zero)

            SUB     A2,A0,A1                    ; A2 <= TLIM/BlinkSpeed - DefIncrementVal
            ADDI    Zero,A1,MinBlinkSpeed
            BLT     A2,A1,IntHandlerCleanup

            SW      A2,TLIM(Zero)               ; If it's not past the min, store it.

            ADDI    Zero,A1,StateSpeed          
            LW      A2,0(A1)                    ; A2 <= StateSpeed contents 
            SUBI    A2,A2,1                     ; A2 <= A2 - 1     
            SW      A2,0(A1)                    ; Update the StateSpeed (for the HEX display)

            BR      IntHandlerCleanup

    ; Switch Handler
    Switch:
        
        ; TODO: Do I need to check SWCTRL here first for the ready bit?

        LW      A0,SW(Zero)                     ; A0 <= SWDATA
        ORI     A0,A0,1                         ; Force SW[0] to always be on so HEX[0] is always on.

        ADDI    Zero,A2,0                       ; A2 <= hex contents, [23:0]
        ADDI    Zero,A1,0                       ; A1 <= extract the on switches from A0.
        DisplayHexLoop:
            ADDI   Zero,A3,4                    ; A3 <= shift amount
            LSHF   A2,A2,A3                     ; A2 <= A2 << 4 

            ; A0[0] is 1, we OR StateSpeed. Otherwise, we just skip downward.
            ANDI   A0,A1,1                      ; Check SW[0]
            RSHF   A0,A0,1                      ; A0 <= A0 << 1

            ADDI   Zero,A3,1                    ; A3 <= 1
            BNE    A1,A3,NextHex                ; A1 != A3 (SW[0] != 1)

            ADDI   Zero,A1,StateSpeed
            LW     A3,0(A1)                     ; Store the current contents of StateSpeed.
            OR     A2,A2,A3                     ; Put StateSpeed into the new place we've made for it. 
            
            NextHex:
                BNE     A0,Zero,DisplayHexLoop      ; A0 != 0, continue to loop to fill A2.

        SW      A2,HEX(Zero)                    ; Store the hex contents into HEX.

        BR      IntHandlerCleanup

    IntHandlerCleanup: 
        ; Restore general purpose registers to the stack
        ; TODO: if you change the top part, gotta change this part.
        LW      A0,0(SSP)
        LW      A1,4(SSP)
        LW      A2,8(SSP)
        LW      A3,12(SSP)
        ADDI    SSP,SSP,16

        ; Return, enable interrupts
        RETI

; -----------------------------------------------------------------
StackTopVal:
.WORD StkTop

; Addresses for I/O
.NAME	HEX=  0xFFFFF000
.NAME	LEDR= 0xFFFFF020

.NAME	KEY=  0xFFFFF080
.NAME   KEYCTL=  0xFFFFF084

.NAME	SW=   0xFFFFF090
.NAME   SWCTL= 0xFFFFF094

.NAME   TIMER= 0xFFFFF100
.NAME   TLIM= 0xFFFFF104
.NAME   TCTL= 0xFFFFF108

; The stack is at the top of memory
.NAME	StkTop=65536

; LED states
.NAME   UpperHalf=0x3E0         ; 11111 00000
.NAME   LowerHalf=0x01F         ; 00000 11111

; Store current state speed value (for hex display)
.NAME   DefStateSpeed=2

.NAME   DefBlinkSpeed=500
.NAME   DefIncrementVal=250

.NAME   MinBlinkSpeed=250
.NAME   MaxBlinkSpeed=2000

; -----------------------------------------------------------------
; Processor Initialization
.ORG 0x100
	XOR		 Zero,Zero,Zero						; Put a zero in the Zero register
	LW		 SP,StackTopVal(Zero)			    ; Load the initial stack-top value into the SP
	SW       Zero,LEDR(Zero)				    ; Turn off LEDR

    ; Setup speed display
    ADDI    Zero,S0,DefStateSpeed               ; Default speed state is at 4.
                                                ; We incr/decr based on each key.
                                                ; The digit we use to display is based on whichever switch is on (the first from the right)
    SW      S0,HEX(Zero)

    ; Initialize state machine counter.
    ADDI 	Zero,S1,0

    ; Write BFIH address.
    ADDI	Zero,T0,0x1000
	WSR		IHA,T0

    ; Enable interrupts in all devices:
    ADDI    Zero,T0,0x10
    SW      T0,KEYCTL(Zero)
    SW      T0,SWCTL(Zero)

    ; Initialize our counter using the new Timer module; we count down from A0 (BlinkSpeed) and reset each time.
    SW      T0,TCTL(Zero)
    ADDI    Zero,S2,DefBlinkSpeed
    SW      S2,TLIM(Zero)                    ; Store BlinkSpeed at TLIM (0xFFFFF104)

    ; Enable interrupts in the processor.
    ADDI    Zero,T0,0x01
    WSR     PCS,T0

    Forever:
         JMP     Forever(Zero)                ; The BFIH handles checking current blinking state speed, 
                                                 ; changing the LEDR location.
   
; -----------------------------------------------------------------
; Interrupt Handler (BFIH)
.ORG 0x1000
    IntHandler:
    ; save general purpose registers to the (system) stack
    ; TODO: which registers to save? 
    ADDI SSP,SSP,-20
    SW A0,0(SSP)
    SW A1,4(SSP)
    SW A2,8(SSP)
    SW A3,12(SSP)
    SW T0,16(SSP)

    RSR     A0,IDN ; Get cause of Interrupt

    ; Decide what to do based on A0
    ; We'll do this on a case by case basis so we don't have an interrupt vector table.
    ADDI    Zero,A1,1
    BEQ     A0,A1,Timer         ; timer-id = 1
    ADDI    A1,A1,1
    BEQ     A0,A1,Key           ; key-id = 2
    ADDI    A1,A1,1             
    BEQ     A0,A1,Switch        ; sw-id = 3
    ADDI    A1,A1,1             

    ; TODO - are interrupt handlers for LEDR/HEX necessary?     

    ; Timer Handler
    Timer:
        LW		T0,TCTL(Zero)               ; unset the ready bit
	    ANDI	T0,T0,0xFFFFFFFE
	    SW		T0,TCTL(Zero)

        ; show halves of the LEDR based on counter.
        ; We store the state counter in S1.

        ; Check if counter is 18 or above:
        ADDI    Zero,A2,17
        BGT     S1,A2,ResetCounter      ; Check if current counter > 17
        BR      StateMachine

        ResetCounter:
            ADDI    Zero,S1,0           ; S1 <= 0

        StateMachine:
            ADDI    Zero,A2,0
            BEQ     S1,A2,State0
            ADDI    Zero,A2,2
            BEQ     S1,A2,State2
            ADDI    Zero,A2,4
            BEQ     S1,A2,State4
            ADDI    Zero,A2,6
            BEQ     S1,A2,State6
            ADDI    Zero,A2,8
            BEQ     S1,A2,State8
            ADDI    Zero,A2,10
            BEQ     S1,A2,State10
            ADDI    Zero,A2,12
            BEQ     S1,A2,State12
            ADDI    Zero,A2,13
            BEQ     S1,A2,State13
            ADDI    Zero,A2,14
            BEQ     S1,A2,State14
            ADDI    Zero,A2,15
            BEQ     S1,A2,State15
            ADDI    Zero,A2,16
            BEQ     S1,A2,State16
            ADDI    Zero,A2,17
            BEQ     S1,A2,State17

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
            ADDI    S1,S1,1
            

            BR IntHandlerCleanup

    ; Key Handler
    Key:
        ADDI    Zero,A2,1
        LW      A0,KEY(Zero)
        ANDI    A0,A1,1                         ; Check Key[0]
        BEQ     A1,A2,IncrLen                   ; If Key[0] == 1, increase length of timer (increase blinkspeed)
        ADDI    Zero,A2,2
        ANDI    A0,A1,2
        BEQ     A1,A2,DecrLen
        BR      Switch

        IncrLen:
            ADDI    Zero,A1,DefIncrementVal
            LW      A0,TLIM(Zero)

            ADD     A2,A0,A1                    ; A2 <= TLIM/BlinkSpeed + DefIncrementVal
            ADDI    Zero,A1,MaxBlinkSpeed
            BGT     A2,A1,Switch 

            SW      A2,TLIM(Zero)               ; If it's not past the max, store it.

            ADDI    S0,S0,1
            SW      S0,HEX(Zero)
            BR      Switch
        
        DecrLen:
            ADDI    Zero,A1,DefIncrementVal
            LW      A0,TLIM(Zero)

            SUB     A2,A0,A1                    ; A2 <= TLIM/BlinkSpeed - DefIncrementVal
            ADDI    Zero,A1,MinBlinkSpeed
            BLT     A2,A1,Switch

            SW      A2,TLIM(Zero)               ; If it's not past the min, store it.

            SUBI    S0,S0,1
            SW      S0,HEX(Zero)
            BR      Switch

    ; Switch Handler
    Switch:  
        LW      A0,SW(Zero)                     ; A0 <= SWDATA
        ORI     A0,A0,1                         ; Force SW[0] to always be on so HEX[0] is always on.
        ANDI    A0,A0,0x3F                      ; Don't check SW[6..9]

        ; S1 <= current state speed value
        ; A2 <= Total HEX.
        ADDI    Zero,A2,0

        ; check SW[0]
        ADDI    Zero,A3,1   
        ANDI    A0,A1,1
        
        BNE     A1,A3,CheckSW1

        ADDI    Zero,T0,0
        LSHF    A3,S0,T0                         ; A3 <= S0 << 0        
        OR      A2,A2,A3                            

        ; check SW[1]
        CheckSW1:
            ADDI    Zero,A3,2   
            ANDI    A0,A1,2
        
            BNE     A1,A3,CheckSW2

            ADDI    Zero,T0,4
            LSHF    A3,S0,T0                      ; A3 <= S0 << 4   
            OR      A2,A2,A3

        ; check SW[2]
        CheckSW2:
            ADDI    Zero,A3,4   
            ANDI    A0,A1,4
        
            BNE     A1,A3,CheckSW3

            ADDI    Zero,T0,8
            LSHF    A3,S0,T0                       ; A3 <= S0 << 8
            OR      A2,A2,A3

        ; check SW[3]
        CheckSW3:
            ADDI    Zero,A3,8   
            ANDI    A0,A1,8
        
            BNE     A1,A3,CheckSW4

            ADDI    Zero,T0,12
            LSHF    A3,S0,T0                       ; A3 <= S0 << 12
            OR      A2,A2,A3

        ; check SW[4]
        CheckSW4:
            ADDI    Zero,A3,16
            ANDI    A0,A1,16
        
            BNE     A1,A3,CheckSW5

            ADDI    Zero,T0,16
            LSHF    A3,S0,T0                       ; A3 <= S0 << 16
            OR      A2,A2,A3

        ; check SW[5]
        CheckSW5:
            ADDI    Zero,A3,32
            ANDI    A0,A1,32
        
            BNE     A1,A3,EndCheckSW

            ADDI    Zero,T0,20
            LSHF    A3,S0,T0                       ; A3 <= S0 << 20
            OR      A2,A2,A3

        EndCheckSW:
            SW      A2,HEX(Zero)                    ; Store the hex contents into HEX.

    IntHandlerCleanup: 
        ; Restore general purpose registers to the stack
        ; TODO: if you change the top part, gotta change this part.
        LW      A0,0(SSP)
        LW      A1,4(SSP)
        LW      A2,8(SSP)
        LW      A3,12(SSP)
        LW      T0,16(SSP)
        ADDI    SSP,SSP,20

        ; Return, enable interrupts
        RETI

; -----------------------------------------------------------------
StackTopVal:
.WORD StkTop

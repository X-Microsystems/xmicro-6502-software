;-----------------------------------------------------------------------------
; VDP.S
; XMICRO-VDP DRIVER AND ROUTINES
; 2020
;-----------------------------------------------------------------------------

.IMPORT __XMICRO_VDP_SLOT__, __XMICRO_VDP_START__, __XMICRO_VDP_VECTOR__	;LINKER-GENERATED SYSTEM INFO

.EXPORT VDP_REG, VDP_PALETTE							;VARIABLES
.EXPORT VDP_READ_STATUS, VDP_SET_REG, VDP_SCREEN_ON, VDP_SCREEN_OFF, VDP_SPRITES_ON, VDP_SPRITES_OFF	;PROCEDURES
.CONSTRUCTOR VDP_INIT

;ADDRESS CONSTANTS
	VDP			:= __XMICRO_VDP_START__

.SEGMENT "BSS"
	TEMP:			.RES 2						;TEMPORARY STORAGE FOR NON-INTERRUPT ROUTINES
	VRAM_ADDR:		.RES 3						;VRAM ADDRESS PARAMETER

.SEGMENT "DATA"

	VDP_REG:		.RES 46, $00					;VDP REGISTER DATA MIRROR (USED TO DETERMINE CURRENT VALUES OF WRITE-ONLY REGISTERS)
	VDP_PALETTE:		.RES 32, $00					;VDP PALETTE REGISTER MIRROR

.SEGMENT "ONCE"
;-----------------------------------------------------------------------------
; VDP_INIT
; INITIALIZE THE CARD AND DRIVER, LOAD INTERRUPT VECTOR
;-----------------------------------------------------------------------------
.PROC VDP_INIT
	LDA #.LOBYTE(VDP_ISR)								;LOAD INTERRUPT VECTOR WITH VDP_ISR ADDRESS
	STA __XMICRO_VDP_VECTOR__
	LDA #.HIBYTE(VDP_ISR)
	STA __XMICRO_VDP_VECTOR__+1


	RTS
.ENDPROC

.SEGMENT "CODE"
;-----------------------------------------------------------------------------
; VDP_ISR
; INTERRUPT SERVICE ROUTINE
;-----------------------------------------------------------------------------
.PROC VDP_ISR
	RTI
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_READ_STATUS
; READ A VDP STATUS REGISTER
; A: STATUS REGISTER NUMBER
; RETURNS A: STATUS REGISTER DATA
;-----------------------------------------------------------------------------
.PROC VDP_READ_STATUS
	STA VDP_REG+15								;SAVE THE VALUE TO BE WRITTEN TO R#15
	SEI
	STA VDP+1								;WRITE THE VALUE TO THE VDP
	LDA #15+128
	STA VDP+1								;WRITE THE CONTROL REGISTER NUMBER TO THE VDP
	LDA VDP+1								;READ THE STATUS REGISTER DATA
	CLI
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_SET_REG
; SET A SINGLE VDP REGISTER
; X: REGISTER NUMBER, A: DATA
; CLOBBERS A
;-----------------------------------------------------------------------------
.PROC VDP_SET_REG
	STA VDP_REG,X								;SAVE THE REGISTER DATA TO CPU RAM
	SEI
	STA VDP+1								;WRITE THE VALUE TO THE VDP
	TXA
	ORA #%10000000								;SET BIT 7 ON THE CONTROL REGISTER NUMBER
	STA VDP+1								;WRITE THE CONTROL REGISTER NUMBER TO THE VDP
	CLI
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_COPY_REGS
; SET MULTIPLE REGISTERS
; X: FIRST REGISTER, A: LAST REGISTER
;-----------------------------------------------------------------------------
.PROC VDP_COPY_REGS
;	STX VDP_REG+17								;SAVE THE REGISTER DATA TO CPU RAM
	SEI
	STA TEMP
	STX VDP+1
	LDA #17+128
	STA VDP+1

@L1:	LDA VDP_REG,X
	STA VDP+3								;STORE REGISTER R#X DATA
	INX
	CPX TEMP
	BPL @L1									;LOOP UNTIL THE LAST REGISTER IS COMPLETE

	CLI
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_COPY_PALETTES
; SET PALETTES (PALETTE NUMBERS MUST BE DOUBLED DUE TO 16-BIT VALUES)
; X: FIRST PALETTEx2, A: LAST PALETTEx2
;-----------------------------------------------------------------------------
.PROC VDP_COPY_PALETTES
;	STX VDP_REG+16								;SAVE THE REGISTER DATA TO CPU RAM
	SEI
	STA TEMP
	STX VDP+1
	LDA #16+128
	STA VDP+1

@L1:	LDA VDP_PALETTE,X
	STA VDP+2								;STORE PALETTE DATA
	INX
	CPX TEMP
	BPL @L1									;LOOP UNTIL THE LAST PALETTE IS COMPLETE

	CLI
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_MODE
; SET SCREEN MODE AND MODE-SPECIFIC DEFAULTS
;-----------------------------------------------------------------------------
.PROC VDP_MODE
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_SCREEN_ON
; ENABLE DISPLAY OUTPUT
; CLOBBERS A, X
;-----------------------------------------------------------------------------
.PROC VDP_SCREEN_ON
	LDA VDP_REG+1								;LOAD THE CURRENT VALUE OF R#1
	ORA #%01000000								;SET THE SCREEN BLANK BIT
	LDX #1									;LOAD REGISTER NUMBER (R#1)
	JMP VDP_SET_REG								;SET THE REGISTER (LET THE OTHER ROUTINE DO THE RTS)
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_SCREEN_OFF
; DISABLE DISPLAY OUTPUT
; CLOBBERS A, X
;-----------------------------------------------------------------------------
.PROC VDP_SCREEN_OFF
	LDA VDP_REG+1								;LOAD THE CURRENT VALUE OF R#1
	AND #%10111111								;CLEAR THE SCREEN BLANK BIT
	LDX #1									;LOAD REGISTER NUMBER (R#1)
	JMP VDP_SET_REG								;SET THE REGISTER (LET THE OTHER ROUTINE DO THE RTS)
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_SPRITES_ON
; ENABLE SPRITES
; CLOBBERS A, X
;-----------------------------------------------------------------------------
.PROC VDP_SPRITES_ON
	LDA VDP_REG+8								;LOAD THE CURRENT VALUE OF R#8
	AND #%11111101								;CLEAR THE SPRITE DISABLE BIT
	LDX #8									;LOAD REGISTER NUMBER (R#8)
	JMP VDP_SET_REG								;SET THE REGISTER (LET THE OTHER ROUTINE DO THE RTS)
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_SPRITES_OFF
; DISABLE SPRITES
; CLOBBERS A, X
;-----------------------------------------------------------------------------
.PROC VDP_SPRITES_OFF
	LDA VDP_REG+8								;LOAD THE CURRENT VALUE OF R#8
	ORA #%00000010								;SET THE SPRITE DISABLE BIT
	LDX #8									;LOAD REGISTER NUMBER (R#8)
	JMP VDP_SET_REG								;SET THE REGISTER (LET THE OTHER ROUTINE DO THE RTS)
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_WAIT_READY
; CHECK IF THE VDP "TRANSFER READY" BIT IS SET. IF NOT, WAIT UNTIL IT IS.
; CLOBBERS A, X
;-----------------------------------------------------------------------------
.PROC VDP_WAIT_READY
	LDA #2									;SELECT S#2
	JSR VDP_READ_STATUS							;READ S#2
	BIT #%10000000
	BEQ VDP_WAIT_READY							;LOOP IF THE TRANSFER READY BIT IS CLEAR (NOT READY)
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_WRITE
; SET UP VRAM WRITE
; CLOBBERS A, X, SETS INTERRUPT MASK (REMEMBER TO CLI WHEN FINISHED!)
;-----------------------------------------------------------------------------
.PROC VDP_WRITE

.ENDPROC

;-----------------------------------------------------------------------------
; VDP_READ
; SET UP VRAM READ
; CLOBBERS A, X, SETS INTERRUPT MASK (REMEMBER TO CLI WHEN FINISHED!)
;-----------------------------------------------------------------------------
.PROC VDP_READ

.ENDPROC




;- VDP_SCREEN_ON		;ENABLE DISPLAY OUTPUT
;- VDP_SCREEN_OFF	;DISABLE DISPLAY OUTPUT
;- VDP_SPRITES_ON
;- VDP_SPRITES_OFF
;- VDP_WAIT_READY	;CHECK IF VDP IS READY (COMMAND IN PROGRESS)
;- VDP_READ_STATUS	;READ A STATUS REGISTER
;- VDP_SET_REG		;SET A SINGLE VDP REGISTER
;- VDP_COPY_REGS		;SET MULTIPLE REGISTERS
;- VDP_COPY_PALETTES
; VDP_MODE		;SET SCREEN MODE AND MODE-SPECIFIC DEFAULTS
; VDP_READ		;SET UP VRAM READ
; VDP_WRITE		;SET UP VRAM WRITE

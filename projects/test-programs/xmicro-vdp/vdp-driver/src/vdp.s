;-----------------------------------------------------------------------------
; VDP.S
; XMICRO-VDP ROUTINES
; 2020-06-07
;-----------------------------------------------------------------------------

.IMPORT __XMICRO_VDP_SLOT__, __XMICRO_VDP_START__, __XMICRO_VDP_VECTOR__	;LINKER-GENERATED SYSTEM INFO

.EXPORT VDP_REG, VDP_PALETTE, VRAM_ADDR						;VARIABLES
.EXPORT VDP_READ_STATUS, VDP_SET_REG, VDP_SCREEN_ON, VDP_SCREEN_OFF		;PROCEDURES
.EXPORT VDP_SPRITES_ON, VDP_SPRITES_OFF, VDP_WAIT_READY, VDP_WRITE, VDP_READ
.EXPORT VDP_MODE
.CONSTRUCTOR VDP_INIT

;MACROS
;-----------------------------------------------------------------------------
; DI
; DISABLE VDP INTERRUPTS
;-----------------------------------------------------------------------------
.MACRO DI
		SEI
.ENDMACRO

;-----------------------------------------------------------------------------
; EI
; ENABLE VDP INTERRUPTS
;-----------------------------------------------------------------------------
.MACRO EI
		CLI
.ENDMACRO


;ADDRESS CONSTANTS
	VDP			:= __XMICRO_VDP_START__

;VARIABLES
.SEGMENT "BSS"
	TEMP:			.RES 2						;TEMPORARY STORAGE FOR NON-INTERRUPT ROUTINES
	VRAM_ADDR:		.RES 3						;VRAM ADDRESS PARAMETER

.SEGMENT "DATA"

	VDP_REG:		.RES 46, $00					;VDP REGISTER DATA MIRROR (USED TO DETERMINE CURRENT VALUES OF WRITE-ONLY REGISTERS)
	VDP_PALETTE:		.RES 32, $00					;VDP PALETTE REGISTER MIRROR

;PROCEDURES
.SEGMENT "ONCE"
;-----------------------------------------------------------------------------
; VDP_INIT
; INITIALIZE THE CARD AND DRIVER, LOAD INTERRUPT VECTOR
;-----------------------------------------------------------------------------
.PROC VDP_INIT
	;LOAD INTERRUPT VECTOR WITH VDP_ISR ADDRESS
	LDA #.LOBYTE(VDP_ISR)
	STA __XMICRO_VDP_VECTOR__
	LDA #.HIBYTE(VDP_ISR)
	STA __XMICRO_VDP_VECTOR__+1

	;SET REGISTERS R#0-R#13
	LDX #$00								;SET UP VDP FOR SEQUENTIAL REGISTER WRITES, STARTING AT R#0
	STX VDP+1
	LDA #17+128
	STA VDP+1
@L1:	LDA T1_INIT_VALUES,X							;TABLE OF INITIAL VALUES FOR R#0-R#13
	STA VDP_REG,X
	STA VDP+3								;STORE REGISTER R#X DATA
	INX
	CPX #14
	BNE @L1									;LOOP UNTIL R#13 IS WRITTEN

	;SET UP R#25 (V9958-SPECIFIC SETTINGS)
	LDA #%00000100								;R#25 - CPU WAIT ON
	STA VDP_REG+25
	STA VDP+1								;WRITE THE VALUE TO THE VDP
	LDA #25+128
	STA VDP+1								;WRITE THE CONTROL REGISTER NUMBER TO THE VDP

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
	DI
	STA VDP+1								;WRITE THE VALUE TO THE VDP
	LDA #15+128
	STA VDP+1								;WRITE THE CONTROL REGISTER NUMBER TO THE VDP
	LDA VDP+1								;READ THE STATUS REGISTER DATA
	EI
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
	DI
	STA VDP+1								;WRITE THE VALUE TO THE VDP
	TXA
	ORA #%10000000								;SET BIT 7 ON THE CONTROL REGISTER NUMBER
	STA VDP+1								;WRITE THE CONTROL REGISTER NUMBER TO THE VDP
	EI
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_COPY_REGS
; SET MULTIPLE REGISTERS
; X: FIRST REGISTER, A: LAST REGISTER
;-----------------------------------------------------------------------------
.PROC VDP_COPY_REGS
;	STX VDP_REG+17								;SAVE THE REGISTER DATA TO CPU RAM
	DI
	STA TEMP
	STX VDP+1
	LDA #17+128
	STA VDP+1

@L1:	LDA VDP_REG,X
	STA VDP+3								;STORE REGISTER R#X DATA
	INX
	CPX TEMP
	BPL @L1									;LOOP UNTIL THE LAST REGISTER IS COMPLETE

	EI
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_COPY_PALETTES
; SET PALETTES (PALETTE NUMBERS MUST BE DOUBLED DUE TO 16-BIT VALUES)
; X: FIRST PALETTEx2, A: LAST PALETTEx2
;-----------------------------------------------------------------------------
.PROC VDP_COPY_PALETTES
;	STX VDP_REG+16								;SAVE THE REGISTER DATA TO CPU RAM
	DI
	STA TEMP
	STX VDP+1
	LDA #16+128
	STA VDP+1

@L1:	LDA VDP_PALETTE,X
	STA VDP+2								;STORE PALETTE DATA
	INX
	CPX TEMP
	BPL @L1									;LOOP UNTIL THE LAST PALETTE IS COMPLETE

	EI
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
; SET UP VRAM WRITE. TAKES A 17-BIT VRAM ADDRESS FROM VRAM_ADDR (NO BANKING)
; CLOBBERS A, DISABLES INTERRUPTS (REMEMBER TO EI WHEN FINISHED WRITING!)
;-----------------------------------------------------------------------------
.PROC VDP_WRITE
	;SET UP A16..A14
	LDA VRAM_ADDR+2
	ROR									;PLACE A16 IN THE CARRY FLAG
	LDA VRAM_ADDR+1								;LOAD A15..A8
	ROL									;ROTATE A16..A14 INTO POSITION FOR R#14
	ROL
	ROL
	AND #%00000111
	DI
	STA VDP+1								;WRITE R#14 VALUE TO THE VDP (A16..A14)
	LDA #14+128
	STA VDP+1								;WRITE THE CONTROL REGISTER NUMBER TO THE VDP

	;SET UP A7..A0
	LDA VRAM_ADDR+0
	; STA VDP_REG+1
	STA VDP+1

	;SET UP A13..A8, WRITE
	LDA VRAM_ADDR+1
	AND #%00111111								;MASK A13..A8
	ORA #%01000000								;SET WRITE BIT
	STA VDP+1

	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_READ
; SET UP VRAM READ. TAKES A 17-BIT VRAM ADDRESS FROM VRAM_ADDR (NO BANKING)
; CLOBBERS A, DISABLES INTERRUPTS (REMEMBER TO EI WHEN FINISHED WRITING!)
;-----------------------------------------------------------------------------
.PROC VDP_READ
	;SET UP A16..A14
	LDA VRAM_ADDR+2
	ROR									;PLACE A16 IN THE CARRY FLAG
	LDA VRAM_ADDR+1								;LOAD A15..A8
	ROL									;ROTATE A16..A14 INTO POSITION FOR R#14
	ROL
	ROL
	AND #%00000111
	DI
	STA VDP+1								;WRITE R#14 VALUE TO THE VDP (A16..A14)
	LDA #14+128
	STA VDP+1								;WRITE THE CONTROL REGISTER NUMBER TO THE VDP

	;SET UP A7..A0
	LDA VRAM_ADDR+0
	; STA VDP_REG+1
	STA VDP+1

	;SET UP A13..A8, WRITE
	LDA VRAM_ADDR+1
	AND #%00111111								;MASK A13..A8, SET READ
	STA VDP+1

	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; VDP_MODE
; SET SCREEN MODE
; A: SCREEN MODE VALUE (M5..M1) - ; MODE NUMBER = 0 0 0 M1 M2 M5 M4 M3
; CLOBBERS A, X
;-----------------------------------------------------------------------------
.PROC VDP_MODE
	TAY									;STORE THE ORIGINAL MODE ID FOR LATER

	;SET UP R#1
	LDA VDP_REG+1								;MASK OFF THE MODE BITS IN R#1 (M1..M0)
	AND #%11100111
	STA VDP_REG+1
	TYA
	AND #%00011000								;ISOLATE THE NEW MODE BITS FOR R#1
	ORA VDP_REG+1								;INSERT THE NEW MODE BITS TO EXISTING R#1 DATA
	LDX #1									;WRITE NEW VALUE TO R#1
	JSR VDP_SET_REG

	;SET UP R#0
	LDA VDP_REG+0								;MASK OFF THE MODE BITS IN R#0 (M3..M1)
	AND #%11110001
	STA VDP_REG+0
	TYA
	ROL									;MOVE THE NEW MODE BITS INTO POSITION FOR R#0
	AND #%00001110								;ISOLATE THE NEW MODE BITS FOR R#0
	ORA VDP_REG+0								;INSERT THE NEW MODE BITS TO EXISTING R#0 DATA
	LDX #0									;WRITE NEW VALUE TO R#0
	JSR VDP_SET_REG

	RTS
.ENDPROC


.SEGMENT "RODATA"
	T1_INIT_VALUES:
	.BYTE %00000000								;R#0 - NO HBLANK, MODE (HIGH) T1
	.BYTE %00010000								;R#1 - SCREEN OFF, NO VBLANK, MODE (LOW) T1, SPRITES 8X8
	.BYTE %00000000								;R#2 - PATTERN LAYOUT TABLE $00000
	.BYTE %00000000								;R#3 - COLOR TABLE (LOW) $00000
	.BYTE %00000001								;R#4 - PATTERN GENERATOR TABLE $00800
	.BYTE %00000000								;R#5 - SPRITE ATTRIBUTE TABLE (LOW) $00000
	.BYTE %00000000								;R#6 - SPRITE PATTERN GENERATOR TABLE $00000
	.BYTE %11110001								;R#7 - TEXT COLOR $F (WHITE), BACKGROUND COLOR $1 (BLACK)
	.BYTE %00001010								;R#8 - TRANSPARENCY ON, VRAM 64KX4, SPRITES DISABLED, COLOR ON
	.BYTE %00000000								;R#9 - 192 LINES, PROGRESSIVE, SINGLE FIELD, NTSC
	.BYTE %00000000								;R#10 - COLOR TABLE (HIGH) $00000
	.BYTE %00000000								;R#11 - SPRITE ATTRIBUTE TABLE (HIGH) $00000
	.BYTE %00000000								;R#12 - BLINK COLOR 1 $0, BLINK COLOR 2 $0
	.BYTE %01100110								;R#13 - BLINK ON 1 SECOND, BLINK OFF 1 SECOND

;-----------------------------------------------------------------------------
; VDP.INC
; INCLUDES FOR VDP.S
; 2020-06-07
;-----------------------------------------------------------------------------
.IMPORT VDP_REG, VDP_PALETTE, VRAM_ADDR							;VARIABLES
.IMPORT VDP_READ_STATUS, VDP_SET_REG, VDP_SCREEN_ON, VDP_SCREEN_OFF
.IMPORT VDP_SPRITES_ON, VDP_SPRITES_OFF, VDP_WAIT_READY, VDP_WRITE, VDP_READ, VDP_MODE	;PROCEDURES
.IMPORT VDP_INIT

.IMPORT __XMICRO_VDP_START__
VDP := __XMICRO_VDP_START__

;MACROS
.MACRO VDP_WREG VAL, REG
	LDA VAL
	LDX REG
	JSR VDP_SET_REG
.ENDMACRO

.MACRO VDP_RSTAT REG
	LDA REG
	JSR VDP_READ_STATUS
.ENDMACRO

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

;-----------------------------------------------------------------------------
; COPY ADDRESS AND SET UP VRAM WRITE
;-----------------------------------------------------------------------------
.MACRO VRAM_SETWRITE SRC
	.IF (.MATCH (.LEFT (1, {SRC}), #))			;IMMEDIATE MODE
		LDA #.LOBYTE(.LOWORD(.RIGHT (.TCOUNT ({SRC})-1, {SRC})))
		STA VRAM_ADDR
		LDA #.HIBYTE(.LOWORD(.RIGHT (.TCOUNT ({SRC})-1, {SRC})))
		STA 1+VRAM_ADDR
		LDA #.LOBYTE(.HIWORD(.RIGHT (.TCOUNT ({SRC})-1, {SRC})))
		STA 2+VRAM_ADDR
	.ELSE							;ASSUME ABSOLUTE OR ZERO PAGE
		LDA SRC
		STA VRAM_ADDR
		LDA 1+SRC
		STA 1+VRAM_ADDR
		LDA 2+SRC
		STA 2+VRAM_ADDR
	.ENDIF
	JSR VDP_WRITE
.ENDMACRO

;-----------------------------------------------------------------------------
; COPY ADDRESS AND SET UP VRAM READ
;-----------------------------------------------------------------------------
.MACRO VRAM_SETREAD SRC
	.IF (.MATCH (.LEFT (1, {SRC}), #))			;IMMEDIATE MODE
		LDA #.LOBYTE(.LOWORD(.RIGHT (.TCOUNT ({SRC})-1, {SRC})))
		STA VRAM_ADDR
		LDA #.HIBYTE(.LOWORD(.RIGHT (.TCOUNT ({SRC})-1, {SRC})))
		STA 1+VRAM_ADDR
		LDA #.LOBYTE(.HIWORD(.RIGHT (.TCOUNT ({SRC})-1, {SRC})))
		STA 2+VRAM_ADDR
	.ELSE							;ASSUME ABSOLUTE OR ZERO PAGE
		LDA SRC
		STA VRAM_ADDR
		LDA 1+SRC
		STA 1+VRAM_ADDR
		LDA 2+SRC
		STA 2+VRAM_ADDR
	.ENDIF
	JSR VDP_READ
.ENDMACRO

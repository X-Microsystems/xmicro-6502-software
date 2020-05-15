;-----------------------------------------------------------------------------
; VDP.S
; XMICRO-VDP DRIVER AND ROUTINES
; 2020
;-----------------------------------------------------------------------------
.IMPORT VDP_REG, VDP_PALETTE							;VARIABLES
.IMPORT VDP_READ_STATUS, VDP_SET_REG, VDP_SCREEN_ON, VDP_SCREEN_OFF, VDP_SPRITES_ON, VDP_SPRITES_OFF	;PROCEDURES


.MACRO VDP_WREG VAL, REG
	LDA VAL
	LDX REG
	JSR VDP_SET_REG
.ENDMACRO

.MACRO VDP_RSTAT REG
	LDA REG
	JSR VDP_READ_STATUS
.ENDMACRO

;-----------------------------------------------------------------------------
; MAIN.S
; CODE TO EXECUTE AFTER INITIALIZING THE SYSTEM
;-----------------------------------------------------------------------------

.INCLUDE "INSTRUCTIONS.MAC"
.INCLUDE "FAT.MAC"

.IMPORT __BANK0_START__, __BANK0_SIZE__			;SEGMENT INFORMATION

.EXPORT _MAIN						;CODE LABELS

.SEGMENT "DATA"
	S_AUTOEXECBIN:		.ASCIIZ "AUTOEXECBIN"

.SEGMENT "CODE"
_MAIN:
	FS_LOAD S_AUTOEXECBIN, __BANK0_START__, #__BANK0_SIZE__
	JMP __BANK0_START__							;BEGIN LOADED PROGRAM

ERROR_HALT:
	SEI
	WAI									;STOP CPU ON ERROR (ILLUMINATE HALT INDICATOR)

;=====================================================================================================
;	CompactFlash FAT16 Detection
;	Checks the CompactFlash card for the presence of a FAT16 partition
;	If found, displays the lower 2 bytes of the first sector's LBA on an XMICRO-7SEG in slot 5.
;	2018-4-21
;=====================================================================================================

.INCLUDE "INSTRUCTIONS.MAC"
.INCLUDE "FAT.MAC"

.IMPORT __BANK0_START__, __BANK0_SIZE__
.EXPORT _MAIN

.SEGMENT "DATA"
	S_AUTOEXECBIN:		.ASCIIZ "AUTOEXECBIN"

.SEGMENT "CODE"
_MAIN:
	FS_LOAD S_AUTOEXECBIN, __BANK0_START__
	JMP __BANK0_START__							;BEGIN LOADED PROGRAM

ERROR_HALT:
	SEI
	WAI									;STOP CPU ON ERROR (ILLUMINATE HALT INDICATOR)

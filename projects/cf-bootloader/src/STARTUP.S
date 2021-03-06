;-----------------------------------------------------------------------------
; STARTUP.S
; SYSTEM INITIALIZATION
;-----------------------------------------------------------------------------

.INCLUDE "INSTRUCTIONS.MAC"
.INCLUDE "VECTORS.MAC"
.INCLUDE "MOVE.MAC"
.INCLUDE "CFDRIVER.MAC"
.INCLUDE "FAT.MAC"
.INCLUDE "XM7SEG.MAC"

.IMPORT __ZEROPAGE_RUN__, __ZEROPAGE_SIZE__					;SEGMENT INFORMATION
.IMPORT __BANK1_START__, __BANK1_SIZE__			;SEGMENT INFORMATION

.EXPORT _INIT									;CODE LABEL
.EXPORT XMICRO_MEMORY = $7100, ERROR_HALT							;ASSEMBLER CONSTANTS

.SEGMENT "RODATA"
	S_AUTOEXECBIN:		.ASCIIZ "AUTOEXECBIN"

.SEGMENT "STARTUP"
_INIT:
	SEI									;DISABLE INTERRUPTS
	CLD									;CLEAR DECIMAL MODE
	LDX #$FF
	TXS									;INITIALIZE STACK POINTER

	ZEROFILL #__ZEROPAGE_RUN__, #__ZEROPAGE_SIZE__				;INITIALIZE ZERO-PAGE

	VTINIT									;INITIALIZE INTERRUPT VECTOR TABLE

	JSR CF_INIT								;INITIALIZE CF CARD AND DRIVER
	JSR FAT_INIT								;INITIALIZE FAT16 DRIVER
	LDA FAT_STATUS								;CHECK STATUS OF FAT16 DRIVER
	BNE ERROR_HALT

	LDX #$00								;CLEAR REGISTERS
	TXA
	TAY

	FS_LOAD S_AUTOEXECBIN, __BANK1_START__, #__BANK1_SIZE__			;FIND AND LOAD AUTOEXEC.BIN

	SEI
	CLD
	LDX #$FF
	TXS
	JMP __BANK1_START__							;BEGIN LOADED PROGRAM

ERROR_HALT:
	JSR XM7SEG_ERRORCODE
	SEI
	WAI

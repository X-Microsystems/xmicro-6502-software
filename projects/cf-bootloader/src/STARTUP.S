;=====================================================================================================
;	CompactFlash FAT16 Detection
;	Checks the CompactFlash card for the presence of a FAT16 partition
;	If found, displays the lower 2 bytes of the first sector's LBA on an XMICRO-7SEG in slot 5.
;	2018-4-21
;=====================================================================================================
.PC02

;Macros
.INCLUDE "INSTRUCTIONS.MAC"
.INCLUDE "VECTORS.MAC"
.INCLUDE "MOVE.MAC"
.INCLUDE "CFDRIVER.MAC"
.INCLUDE "FAT.MAC"

.EXPORT XMICRO_MEMORY = $1100

.IMPORT __LOWCODE_LOAD__, __LOWCODE_RUN__, __LOWCODE_SIZE__
.IMPORT __DATA_LOAD__, __DATA_RUN__, __DATA_SIZE__
.IMPORT __BSS_RUN__, __BSS_SIZE__
.IMPORT _MAIN
.EXPORT _INIT

.SEGMENT "STARTUP"
_INIT:
	SEI									;DISABLE INTERRUPTS
	CLD									;CLEAR DECIMAL MODE
	LDX #$FF
	TXS									;INITIALIZE STACK POINTER

	ZEROFILL #__BSS_RUN__, #__BSS_SIZE__					;INITIALIZE BSS SEGMENT
	ROM_MOVE #__LOWCODE_LOAD__, #__LOWCODE_RUN__, #__LOWCODE_SIZE__		;INITIALIZE LOWCODE SEGMENT
	ROM_MOVE #__DATA_LOAD__, #__DATA_RUN__, #__DATA_SIZE__			;INITIALIZE DATA SEGMENT

	VTINIT									;INITIALIZE INTERRUPT VECTOR TABLE

	JSR CF_INIT								;INITIALIZE CF CARD AND DRIVER
	JSR FAT_INIT								;INITIALIZE FAT16 DRIVER
	LDA FAT_STATUS								;CHECK STATUS OF FAT16 DRIVER
	BNE STARTUP_ERROR

	LDX #$00								;CLEAR REGISTERS
	TXA
	TAY
	CLI									;ENABLE INTERRUPTS

	JMP _MAIN

STARTUP_ERROR:
	SEI
	WAI

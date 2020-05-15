;-----------------------------------------------------------------------------
; crt0.s
; Startup code for cc65 (XMICRO-6502)
;-----------------------------------------------------------------------------

.EXPORT _init, _exit
.IMPORT _main

.EXPORT __STARTUP__ : absolute = 1						;Mark as startup
.IMPORT __BANK01_START__, __BANK01_SIZE__					;Linker generated

.IMPORT copydata, zerobss, initlib, donelib

.INCLUDE "zeropage.inc"

;-----------------------------------------------------------------------------
; Place the startup code in a special segment

.SEGMENT "STARTUP"

;-----------------------------------------------------------------------------
; A little light 6502 housekeeping

_init:	LDX #$FF								;Initialize stack pointer to $01FF
	TXS
	CLD									;Clear decimal mode

;-----------------------------------------------------------------------------
; Set cc65 argument stack pointer
	LDA #<(__BANK01_START__ + __BANK01_SIZE__)
	STA sp
	LDA #>(__BANK01_START__ + __BANK01_SIZE__)
	STA sp+1

;-----------------------------------------------------------------------------
; Initialize memory storage
	JSR zerobss								;Clear BSS segment
; 	JSR copydata								;Initialize DATA segment
	JSR initlib								;Run constructors
	CLI									;Enable interrupts

;-----------------------------------------------------------------------------
; Call main()
	JSR _main

;-----------------------------------------------------------------------------
; Back from main (this is also the _exit entry):  force a software break

_exit:	JSR donelib								; Run destructors
	BRK

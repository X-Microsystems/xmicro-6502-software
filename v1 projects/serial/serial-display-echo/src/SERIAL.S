;-----------------------------------------------------------------------------
; SERIAL.S
; SERIAL TEST DRIVER
; 2018-08-05
;-----------------------------------------------------------------------------

.INCLUDE "INSTRUCTIONS.MAC"
.INCLUDE "XM7SEG.MAC"

.EXPORTZP SERIAL_BUFFER
.EXPORT SERIAL_INIT

;CONSTANTS

	SERIAL_BASE	= $1300
	SERIAL_STATUS	= SERIAL_BASE+1

.SEGMENT "ZEROPAGE"
	SERIAL_BUFFER:	.RES 2

.SEGMENT "CODE"
;-----------------------------------------------------------------------------
; SERIAL_INIT
; INITIALIZE THE SERIAL PORT - LOAD INTERRUPT VECTOR TO IRQ3
;-----------------------------------------------------------------------------
.PROC SERIAL_INIT
	MVA #$4C, $020C
	MWA #SERIAL_ISR, $020D
	LDA #$00
	STA SERIAL_BUFFER
	STA SERIAL_BUFFER+1
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; SERIAL_ISR
; INTERRUPT SERVICE ROUTINE FOR THE SERIAL PORT
;-----------------------------------------------------------------------------
.PROC SERIAL_ISR
	;BIT SERIAL_STATUS

	MVA SERIAL_BASE, SERIAL_BUFFER
	STA SERIAL_BASE
	XM7SEG_WORD SERIAL_BUFFER

	RTI
.ENDPROC

;-----------------------------------------------------------------------------
; XM7SEG.S
; XMICRO-7SEG DRIVER
;-----------------------------------------------------------------------------

.INCLUDE "INSTRUCTIONS.MAC"

.EXPORT XM7SEG_ERRORCODE, XM7SEG_WRITE
.EXPORTZP XM7SEG_BUFFER
.EXPORTZP XM7SEG_ADDRESS

;CONSTANTS
	XM7SEG_ID	= $03			;CARD ID OF XMICRO-7SEG
	SLOT0		= $1000			;ADDRESS OF THE FIRST CARD SLOT
	HIGHSLOT	= $07			;HIGHEST SLOT NUMBER

;VARIABLES
.SEGMENT "ZEROPAGE"
XM7SEG_ADDRESS:		.RES 2			;POINTER TO CARD'S BASE ADDRESS
XM7SEG_BUFFER:		.RES 4			;BUFFER FOR ONBOARD REGISTERS

.SEGMENT "CODE"

;-----------------------------------------------------------------------------
; XM7SEG_ERRORCODE
; FIND THE HIGHEST PRIORITY 7SEG CARD AND DISPLAY AN ERROR CODE
;-----------------------------------------------------------------------------
.PROC XM7SEG_ERRORCODE
	STA XM7SEG_BUFFER+0
	LDA #$00
	STA XM7SEG_BUFFER+1
	STA XM7SEG_BUFFER+2
	LDA #$80
	STA XM7SEG_BUFFER+3

	LDX #HIGHSLOT
	LDY #$FF
	MWA #SLOT0, XM7SEG_ADDRESS	;SET UP ID REGISTER ADDRESS AT SLOT 0
L0:	LDA (XM7SEG_ADDRESS),Y
	CMP #XM7SEG_ID
	BEQ SUCCESS
	INC XM7SEG_ADDRESS+1
	DEX
	BMI FAIL
	JMP L0

FAIL:	MWA #$FFFF, XM7SEG_ADDRESS
	RTS
SUCCESS:
	JSR XM7SEG_WRITE
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; XM7SEG_WRITE
; WRITE BUFFER DATA TO THE CARD
;-----------------------------------------------------------------------------
.PROC XM7SEG_WRITE
	LDY #$03
L0:	LDA XM7SEG_BUFFER,Y
	STA (XM7SEG_ADDRESS),Y
	DEY
	BPL L0
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; XM7SEG.S
; XMICRO-7SEG DRIVER
; 2018-04-21
;-----------------------------------------------------------------------------

.INCLUDE "INSTRUCTIONS.MAC"

.EXPORT XM7SEG_INIT, XM7SEG_WRITE
.EXPORT XM7SEG_BUFFER
.EXPORTZP XM7SEG_ADDRESS

;CONSTANTS
	XM7SEG_ID	= $03			;CARD ID OF XMICRO-7SEG
	SLOT0		= $1000			;ADDRESS OF THE FIRST CARD SLOT
	HIGHSLOT	= $07			;HIGHEST SLOT NUMBER

;VARIABLES
.SEGMENT "ZEROPAGE"
XM7SEG_ADDRESS:		.RES 2			;POINTER TO CARD'S BASE ADDRESS

.SEGMENT "BSS"
XM7SEG_BUFFER:		.RES 4			;BUFFER FOR ONBOARD REGISTERS

.SEGMENT "CODE"

;-----------------------------------------------------------------------------
; XM7SEG_INIT
; FIND THE HIGHEST PRIORITY 7SEG CARD AND ZERO THE DISPLAYS
;-----------------------------------------------------------------------------
.PROC XM7SEG_INIT
	PUSH_AXY
	MDA #$C0000000, XM7SEG_BUFFER	;PREPARE THE BUFFER FOR ZEROED DISPLAYS
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
	PULL_AXY
	RTS
SUCCESS:
	JSR XM7SEG_WRITE
	PULL_AXY
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

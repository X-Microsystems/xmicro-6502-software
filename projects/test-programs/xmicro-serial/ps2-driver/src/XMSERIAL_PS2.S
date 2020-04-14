;-----------------------------------------------------------------------------
; XMSERIAL.S
; XMICRO-SERIAL DRIVER
; 2020-04-10
;-----------------------------------------------------------------------------

.INCLUDE "INSTRUCTIONS.MAC"

.EXPORT XMSERIAL_INIT, PS2_KEYBUFFER, PS2_KEYINDEX

;CONSTANTS
	XM7SEG		= $7400							;****TEMPORARY DEBUG DISPLAY

	XMSERIAL_SLOT	= 2							;BACKPLANE SLOT OF CARD
	CARD_BASE	= $7000+(XMSERIAL_SLOT*$100)
	CARD_IRQ_VECTOR	= $0200+(XMSERIAL_SLOT*$4)

	PS2_DATA	= CARD_BASE+$10						;PS/2 DATA REGISTER

	XMSERIAL_CSR	= CARD_BASE+$11						;CARD STATUS REGISTER

.SEGMENT "BSS"

	PS2_CMDFLAGS:	.RES 1							;COMMAND STATE
	PS2_CMDBUFFER:	.RES $10							;COMMAND BUFFER
	PS2_CMDINDEX:	.RES 1							;COMMAND BUFFER INDEX

	PS2_READFLAGS:	.RES 1							;FLAG BITS FOR KEYBOARD STATE - %RPEB0000 (RESET, PAUSE, EXTENDED, BREAK)
	PS2_SCANCODE:	.RES 1							;CURRENT SCANCODE
	PS2_SCANINDEX:	.RES 1							;SCANCODE INDEX (USED FOR COUNTING DOWN PA/BR SCANCODE)

	PS2_KEYBUFFER:	.RES 20							;KEYCODE BUFFER
	PS2_KEYINDEX:	.RES 1							;KEYCODE BUFFER INDEX


.SEGMENT "CODE"
;-----------------------------------------------------------------------------
; XMSERIAL_INIT
; INITIALIZE THE CARD AND DRIVER, LOAD INTERRUPT VECTOR
;-----------------------------------------------------------------------------
.PROC XMSERIAL_INIT
	MVA #$4C, CARD_IRQ_VECTOR						;LOAD INTERRUPT VECTOR WITH "JMP XMSERIAL_ISR"
	MWA #XMSERIAL_ISR, CARD_IRQ_VECTOR+1

	LDA #$00								;RESET INDEXES
	STA PS2_SCANINDEX
	STA PS2_KEYINDEX
	STA PS2_CMDINDEX
	LDA #$FF								;RESET AND SELF-TEST KEYBOARD HARDWARE
	STA PS2_DATA
	LDA PS2_DATA								;CLEAR DATA REGISTER
	LDA #%10000000								;SET UP RESET FLAG
	STA PS2_READFLAGS

	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; PS2_COMMAND
; SEND A COMMAND TO THE KEYBOARD
; X: COMMAND BYTE
; Y: DATA BYTE
;-----------------------------------------------------------------------------
.PROC PS2_COMMAND
	TYA
	LDY PS2_CMDINDEX
	STA PS2_CMDBUFFER,Y

	TAY
	RTS
.ENDPROC



;-----------------------------------------------------------------------------
; XMSERIAL_ISR
; INTERRUPT SERVICE ROUTINE FOR THE CARD (CURRENTLY PS/2 ONLY)
;-----------------------------------------------------------------------------
.PROC XMSERIAL_ISR
	PUSH_AXY

	LDY PS2_DATA								;LOAD THE LATEST BYTE FROM THE KEYBOARD
	STY PS2_SCANCODE							;STORE IT FOR LATER
	STY XM7SEG								;****TEMPORARY DEBUG DISPLAY

	LDA #%00001000								;CHECK FLAGS FOR CURRENT STATE
	BIT PS2_READFLAGS
	BVC STATE_DEFAULT
	JMP STATE_PABR								;PABR FLAG IS SET

STATE_DEFAULT:									;DEFAULT STATE - DECIDE WHAT TO DO BASED ON CURRENT BYTE
	CPY #$8F								;SKIP THE NEXT SECTION IF IT'S NOT A SPECIAL BYTE (BELOW $90 IS JUST A KEY ID)
	BCC @CHECK_EXT

	CPY #$E0								;IF THE BYTE IS THE START OF AN EXTENDED SCANCODE, SET THE EXT FLAG
	BEQ @SET_EXT
	CPY #$F0								;IF THE BYTE IS THE START OF A BREAK CODE, SET THE BRK FLAG
	BEQ @SET_BRK
	CPY #$E1								;IF THE BYTE IS THE START OF A PAUSE/BREAK SCANCODE, FLAG IT
	BEQ @SET_PABR
	JMP END_ISR								;IGNORE OTHER SPECIAL BYTES

	@CHECK_EXT:								;CHECK IF IT'S AN EXTENDED SCANCODE
		LDA #%00100000
		BIT PS2_READFLAGS
		BNE @EXT_CODE
		LDA PS2_NORMAL_TABLE,Y						;IF IT'S NOT AN EXTENDED CODE, USE THE NORMAL LOOKUP TABLE
		BRA @CHECK_BRK
	@EXT_CODE:								;IF IT'S AN EXTENDED CODE, USE THE EXTENDED LOOKUP TABLE
		LDA PS2_EXT_TABLE,Y
	@CHECK_BRK:								;CONVERT THE SCANCODE TO A KEYCODE
		TAX
		LDY PS2_KEYINDEX
		LDA #%00010000							;CHECK IF IT'S A BREAK CODE
		BIT PS2_READFLAGS
		BNE @BRK_CODE
		TXA
		BRA @STORE_KEYCODE
	@BRK_CODE:								;IF IT'S A BREAK CODE, SET THE KEYCODE BREAK BIT
		TXA
		ORA #%10000000
	@STORE_KEYCODE:								;STORE THE KEYCODE IN THE KEY BUFFER AND END THE ISR
		STA PS2_KEYBUFFER,Y
		STA XM7SEG+1							;****TEMPORARY DEBUG
		INY								;INCREMENT THE KEYCODE BUFFER INDEX
		STY PS2_KEYINDEX
		LDA #$00
		STA PS2_READFLAGS
		JMP END_ISR

	@SET_EXT:								;SET THE EXT FLAG
		LDA #%00100000
		TSB PS2_READFLAGS
		JMP END_ISR
	@SET_BRK:								;SET THE BRK FLAG
		LDA #%00010000
		TSB PS2_READFLAGS
		JMP END_ISR
	@SET_PABR:								;SET THE PABR FLAG AND SCANCODE INDEX
		LDA #%01000000
		TSB PS2_READFLAGS
		MVA #07, PS2_SCANINDEX
		JMP END_ISR

STATE_PABR:									;PABR STATE - IGNORE REMAINING BYTES OF THE PAUSE/BREAK SCANCODE
	DEC PS2_SCANINDEX
	BNE END_ISR
	LDA #%01000000
	TRB PS2_READFLAGS
	JMP END_ISR

END_ISR:									;END THE ISR AND RETURN
	PULL_AXY
	RTI

.ENDPROC


.SEGMENT "RODATA"
;-----------------------------------------------------------------------------
; SCANCODE LOOKUP TABLES
; MAPS THE KEYBOARD SCANCODES TO KEYCODES USED BY THE DRIVER
;
; KEYCODES ARE A ONE-BYTE CODE INDICATING WHICH KEY WAS PRESSED
; VISIBLE CHARACTERS ARE MAPPED TO THEIR UPPERCASE ASCII VALUE
; BIT 7 INDICATES A KEY BREAK
;-----------------------------------------------------------------------------
PS2_NORMAL_TABLE:								;NORMAL SCANCODES
	.BYTE	$00								;00
	.BYTE	$00								;01	F9
	.BYTE	$00								;02
	.BYTE	$00								;03	F5
	.BYTE	$00								;04	F3
	.BYTE	$00								;05	F1
	.BYTE	$00								;06	F2
	.BYTE	$00								;07	F12
	.BYTE	$00								;08
	.BYTE	$00								;09	F10
	.BYTE	$00								;0A	F8
	.BYTE	$00								;0B	F6
	.BYTE	$00								;0C	F4
	.BYTE	$11								;0D	TAB
	.BYTE	"`"								;0E	`
	.BYTE	$00								;0F

	.BYTE	$00								;10
	.BYTE	$00								;11	LALT
	.BYTE	$00								;12	LSHIFT
	.BYTE	$00								;13
	.BYTE	$00								;14	LCTRL
	.BYTE	"Q"								;15	Q
	.BYTE	"1"								;16	1
	.BYTE	$00								;17
	.BYTE	$00								;18
	.BYTE	$00								;19
	.BYTE	"Z"								;1A	Z
	.BYTE	"S"								;1B	S
	.BYTE	"A"								;1C	A
	.BYTE	"W"								;1D	W
	.BYTE	"2"								;1E	2
	.BYTE	$00								;1F

	.BYTE	$00								;20
	.BYTE	"C"								;21	C
	.BYTE	"X"								;22	X
	.BYTE	"D"								;23	D
	.BYTE	"E"								;24	E
	.BYTE	"4"								;25	4
	.BYTE	"3"								;26	3
	.BYTE	$00								;27
	.BYTE	$00								;28
	.BYTE	" "								;29	SPACE
	.BYTE	"V"								;2A	V
	.BYTE	"F"								;2B	F
	.BYTE	"T"								;2C	T
	.BYTE	"R"								;2D	R
	.BYTE	"5"								;2E	5
	.BYTE	$00								;2F

	.BYTE	$00								;30
	.BYTE	"N"								;31	N
	.BYTE	"B"								;32	B
	.BYTE	"H"								;33	H
	.BYTE	"G"								;34	G
	.BYTE	"Y"								;35	Y
	.BYTE	"6"								;36	6
	.BYTE	$00								;37
	.BYTE	$00								;38
	.BYTE	$00								;39
	.BYTE	"M"								;3A	M
	.BYTE	"J"								;3B	J
	.BYTE	"U"								;3C	U
	.BYTE	"7"								;3D	7
	.BYTE	"8"								;3E	8
	.BYTE	$00								;3F

	.BYTE	$00								;40
	.BYTE	","								;41	,
	.BYTE	"K"								;42	K
	.BYTE	"I"								;43	I
	.BYTE	"O"								;44	O
	.BYTE	"0"								;45	0
	.BYTE	"9"								;46	9
	.BYTE	$00								;47
	.BYTE	$00								;48
	.BYTE	"."								;49	.
	.BYTE	"/"								;4A	/
	.BYTE	"L"								;4B	L
	.BYTE	";"								;4C	;
	.BYTE	"P"								;4D	P
	.BYTE	"-"								;4E	-
	.BYTE	$00								;4F

	.BYTE	$00								;50
	.BYTE	$00								;51
	.BYTE	"'"								;52	'
	.BYTE	$00								;53
	.BYTE	"["								;54	[
	.BYTE	"="								;55	=
	.BYTE	$00								;56
	.BYTE	$00								;57
	.BYTE	$00								;58	CAPSLOCK
	.BYTE	$00								;59	RSHIFT
	.BYTE	$0A								;5A	ENTER
	.BYTE	"]"								;5B	]
	.BYTE	$00								;5C
	.BYTE	"\"								;5D	\
	.BYTE	$00								;5E
	.BYTE	$00								;5F

	.BYTE	$00								;60
	.BYTE	$00								;61
	.BYTE	$00								;62
	.BYTE	$00								;63
	.BYTE	$00								;64
	.BYTE	$00								;65
	.BYTE	$08								;66	BACKSPACE
	.BYTE	$00								;67
	.BYTE	$00								;68
	.BYTE	"1"								;69	(KEYPAD) 1
	.BYTE	$00								;6A
	.BYTE	"4"								;6B	(KEYPAD) 4
	.BYTE	"7"								;6C	(KEYPAD) 7
	.BYTE	$00								;6D
	.BYTE	$00								;6E
	.BYTE	$00								;6F

	.BYTE	"0"								;70	(KEYPAD) 0
	.BYTE	"."								;71	(KEYPAD) .
	.BYTE	"2"								;72	(KEYPAD) 2
	.BYTE	"5"								;73	(KEYPAD) 5
	.BYTE	"6"								;74	(KEYPAD) 6
	.BYTE	"8"								;75	(KEYPAD) 8
	.BYTE	$1B								;76	ESC
	.BYTE	$00								;77	NUMLOCK
	.BYTE	$00								;78	F11
	.BYTE	"+"								;79	(KEYPAD) +
	.BYTE	"3"								;7A	(KEYPAD) 3
	.BYTE	"-"								;7B	(KEYPAD) -
	.BYTE	"*"								;7C	(KEYPAD) *
	.BYTE	"9"								;7D	(KEYPAD) 9
	.BYTE	$00								;7E	SCROLLLOCK
	.BYTE	$00								;7F

	.BYTE	$00								;80
	.BYTE	$00								;81
	.BYTE	$00								;82
	.BYTE	$00								;83	F7

PS2_EXT_TABLE:									;EXTENDED SCANCODES
	.BYTE	$00								;00
	.BYTE	$00								;01
	.BYTE	$00								;02
	.BYTE	$00								;03
	.BYTE	$00								;04
	.BYTE	$00								;05
	.BYTE	$00								;06
	.BYTE	$00								;07
	.BYTE	$00								;08
	.BYTE	$00								;09
	.BYTE	$00								;0A
	.BYTE	$00								;0B
	.BYTE	$00								;0C
	.BYTE	$00								;0D
	.BYTE	$00								;0E
	.BYTE	$00								;0F

	.BYTE	$00								;10
	.BYTE	$00								;11	RALT
	.BYTE	$00								;12	PRINTSCREEN
	.BYTE	$00								;13
	.BYTE	$00								;14	RCTRL
	.BYTE	$00								;15
	.BYTE	$00								;16
	.BYTE	$00								;17
	.BYTE	$00								;18
	.BYTE	$00								;19
	.BYTE	$00								;1A
	.BYTE	$00								;1B
	.BYTE	$00								;1C
	.BYTE	$00								;1D
	.BYTE	$00								;1E
	.BYTE	$00								;1F	LGUI

	.BYTE	$00								;20
	.BYTE	$00								;21
	.BYTE	$00								;22
	.BYTE	$00								;23
	.BYTE	$00								;24
	.BYTE	$00								;25
	.BYTE	$00								;26
	.BYTE	$00								;27	RGUI
	.BYTE	$00								;28
	.BYTE	$00								;29
	.BYTE	$00								;2A
	.BYTE	$00								;2B
	.BYTE	$00								;2C
	.BYTE	$00								;2D
	.BYTE	$00								;2E
	.BYTE	$00								;2F

	.BYTE	$00								;30
	.BYTE	$00								;31
	.BYTE	$00								;32
	.BYTE	$00								;33
	.BYTE	$00								;34
	.BYTE	$00								;35
	.BYTE	$00								;36
	.BYTE	$00								;37
	.BYTE	$00								;38
	.BYTE	$00								;39
	.BYTE	$00								;3A
	.BYTE	$00								;3B
	.BYTE	$00								;3C
	.BYTE	$00								;3D
	.BYTE	$00								;3E
	.BYTE	$00								;3F

	.BYTE	$00								;40
	.BYTE	$00								;41
	.BYTE	$00								;42
	.BYTE	$00								;43
	.BYTE	$00								;44
	.BYTE	$00								;45
	.BYTE	$00								;46
	.BYTE	$00								;47
	.BYTE	$00								;48
	.BYTE	$00								;49
	.BYTE	"/"								;4A	(KEYPAD) /
	.BYTE	$00								;4B
	.BYTE	$00								;4C
	.BYTE	$00								;4D
	.BYTE	$00								;4E
	.BYTE	$00								;4F

	.BYTE	$00								;50
	.BYTE	$00								;51
	.BYTE	$00								;52
	.BYTE	$00								;53
	.BYTE	$00								;54
	.BYTE	$00								;55
	.BYTE	$00								;56
	.BYTE	$00								;57
	.BYTE	$00								;58
	.BYTE	$00								;59
	.BYTE	$0A								;5A	(KEYPAD) ENTER
	.BYTE	$00								;5B
	.BYTE	$00								;5C
	.BYTE	$00								;5D
	.BYTE	$00								;5E
	.BYTE	$00								;5F

	.BYTE	$00								;60
	.BYTE	$00								;61
	.BYTE	$00								;62
	.BYTE	$00								;63
	.BYTE	$00								;64
	.BYTE	$00								;65
	.BYTE	$00								;66
	.BYTE	$00								;67
	.BYTE	$00								;68
	.BYTE	$00								;69	END
	.BYTE	$00								;6A
	.BYTE	$00								;6B	LEFT
	.BYTE	$00								;6C	HOME
	.BYTE	$00								;6D
	.BYTE	$00								;6E
	.BYTE	$00								;6F

	.BYTE	$00								;70	INSERT
	.BYTE	$7F								;71	DELETE
	.BYTE	$00								;72	DOWN
	.BYTE	$00								;73
	.BYTE	$00								;74	RIGHT
	.BYTE	$00								;75	UP
	.BYTE	$00								;76
	.BYTE	$00								;77
	.BYTE	$00								;78
	.BYTE	$00								;79
	.BYTE	$00								;7A	PAGEDOWN
	.BYTE	$00								;7B
	.BYTE	$00								;7C	PRINTSCREEN
	.BYTE	$00								;7D	PAGEUP
	.BYTE	$00								;7E
	.BYTE	$00								;7F

	.BYTE	$00								;80
	.BYTE	$00								;81
	.BYTE	$00								;82
	.BYTE	$00								;83

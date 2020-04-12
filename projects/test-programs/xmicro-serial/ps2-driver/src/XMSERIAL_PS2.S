;-----------------------------------------------------------------------------
; XMSERIAL.S
; XMICRO-SERIAL DRIVER
; 2020-04-10
;-----------------------------------------------------------------------------

.INCLUDE "INSTRUCTIONS.MAC"

.EXPORTZP PS2_POINTER
.EXPORT XMSERIAL_INIT, PS2_KEYBUFFER, PS2_KEYINDEX

;CONSTANTS
		XM7SEG		= $7400			;TEMPORARY DEBUG DISPLAY

	XMSERIAL_SLOT	= 2			;BACKPLANE SLOT OF CARD
	CARD_BASE	= $7000+(XMSERIAL_SLOT*$100)
	CARD_IRQ_VECTOR	= $0200+(XMSERIAL_SLOT*$4)

	PS2_DATA	= CARD_BASE+$10		;PS/2 DATA REGISTER

	XMSERIAL_CSR	= CARD_BASE+$11		;CARD STATUS REGISTER

.SEGMENT "ZEROPAGE"
	PS2_POINTER:	.RES 2			;GENERAL-PURPOSE POINTER

.SEGMENT "BSS"

;	PS2_CMDFLAGS:	.RES 1			;COMMAND STATE
;	PS2_CMDBUFFER:	.RES 10			;COMMAND BUFFER
;	PS2_CMDINDEX:	.RES 1			;COMMAND BUFFER INDEX

	PS2_READFLAGS:	.RES 1			;FLAG BITS FOR KEYBOARD STATE - %RPEB0000 (RESET, PAUSE, EXTENDED, BREAK)
	PS2_SCANCODE:	.RES 1			;CURRENT SCANCODE
	PS2_SCANINDEX:	.RES 1			;SCANCODE INDEX (USED FOR COUNTING DOWN PA/BR SCANCODE)

	PS2_KEYBUFFER:	.RES 20			;KEYCODE BUFFER
	PS2_KEYINDEX:	.RES 1			;KEYCODE BUFFER INDEX


.SEGMENT "CODE"
;-----------------------------------------------------------------------------
; XMSERIAL_INIT
; INITIALIZE THE CARD - LOAD INTERRUPT VECTOR
;-----------------------------------------------------------------------------
.PROC XMSERIAL_INIT
	MVA #$4C, CARD_IRQ_VECTOR		;LOAD INTERRUPT VECTOR WITH "JMP XMSERIAL_ISR"
	MWA #XMSERIAL_ISR, CARD_IRQ_VECTOR+1

	LDA #$00				;RESET INDEXES
	STA PS2_SCANINDEX
	STA PS2_KEYINDEX

	LDA #$FF				;RESET AND SELF-TEST KEYBOARD HARDWARE
	STA PS2_DATA
	LDA PS2_DATA				;CLEAR DATA REGISTER
	LDA #%10000000				;SET UP RESET FLAG
	STA PS2_READFLAGS

	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; XMSERIAL_ISR
; INTERRUPT SERVICE ROUTINE FOR THE CARD (CURRENTLY PS/2 ONLY)
;-----------------------------------------------------------------------------
.PROC XMSERIAL_ISR
	PUSH_AXY

	LDY PS2_DATA				;LOAD THE LATEST BYTE FROM THE KEYBOARD
	STY PS2_SCANCODE			;STORE IT FOR LATER
		STY XM7SEG	;TEMPORARY DEBUG DISPLAY

	LDA #%00100000				;CHECK FLAGS
	BIT PS2_READFLAGS
	BMI @RESET
	BVS @PABR
	JMP @DEFAULT_READ

	@RESET:					;CURRENTLY IN THE RESET SEQUENCE, LOOKING FOR $AA
		CPY #$AA
		BEQ @CLEAN_RESET
		WAI
		@CLEAN_RESET:
		LDA #$00
		STA PS2_READFLAGS
		JMP @RETURN

	@PABR:					;CURRENTLY IN A PA/BR KEY SEQUENCE
		DEC PS2_SCANINDEX
		BNE @RETURN
		LDA #%01000000
		TRB PS2_READFLAGS
		JMP @RETURN

@DEFAULT_READ:
	CPY #$E0					;IF THE BYTE IS THE START OF AN EXTENDED CODE, FLAG IT
	BEQ @SET_EXT
	CPY #$F0					;IF THE BYTE IS THE START OF A BREAK CODE, FLAG IT
	BEQ @SET_BRK
	CPY #$E1					;IF THE BYTE IS THE START OF A PAUSE/BREAK SCANCODE, FLAG IT
	BEQ @SET_PABR

	LDA #%00100000
	BIT PS2_READFLAGS
	BNE @EXT_CODE

	@NORMAL_CODE:
		MWA #PS2_NORMAL_TABLE, PS2_POINTER
		JMP @CHECK_BREAK

	@EXT_CODE:
		MWA #PS2_EXT_TABLE, PS2_POINTER
		;JMP @CHECK_BREAK

	@CHECK_BREAK:					;
		LDA (PS2_POINTER),Y			;CONVERT THE SCANCODE TO A KEYCODE (ASCII)
		TAX
		LDA #%00010000
		BIT PS2_READFLAGS
		BNE @BREAK_CODE

		LDY PS2_KEYINDEX
		MWA #PS2_KEYBUFFER, PS2_POINTER		;STORE THE KEYCODE IN THE KEYCODE BUFFER (INDEXED)
		TXA
		STA (PS2_POINTER),Y
			STA XM7SEG+1
		INY					;INCREMENT THE KEYCODE BUFFER INDEX
		STY PS2_KEYINDEX
		LDA #$00
		STA PS2_READFLAGS
		JMP @RETURN

@RETURN:
	PULL_AXY
	RTI

	@BREAK_CODE:
		LDY PS2_KEYINDEX
		MWA #PS2_KEYBUFFER, PS2_POINTER		;STORE THE KEYCODE IN THE KEYCODE BUFFER (INDEXED)
		TXA
		ORA #%10000000
		STA (PS2_POINTER),Y
			STA XM7SEG+1
		INY					;INCREMENT THE KEYCODE BUFFER INDEX
		STY PS2_KEYINDEX
		LDA #$00
		STA PS2_READFLAGS
		JMP @RETURN

	@SET_EXT:
		LDA #%00100000
		TSB PS2_READFLAGS
		JMP @RETURN
	@SET_BRK:
		LDA #%00010000
		TSB PS2_READFLAGS
		JMP @RETURN
	@SET_PABR:
		LDA #%01000000
		TSB PS2_READFLAGS
		MVA #07, PS2_SCANINDEX
		JMP @RETURN


.ENDPROC

.SEGMENT "RODATA"
PS2_NORMAL_TABLE:
					;00
	.BYTE	$00			;0
	.BYTE	$00			;1	F9
	.BYTE	$00			;2
	.BYTE	$00			;3	F5
	.BYTE	$00			;4	F3
	.BYTE	$00			;5	F1
	.BYTE	$00			;6	F2
	.BYTE	$00			;7	F12
	.BYTE	$00			;8
	.BYTE	$00			;9	F10
	.BYTE	$00			;A	F8
	.BYTE	$00			;B	F6
	.BYTE	$00			;C	F4
	.BYTE	$11			;D	TAB
	.BYTE	"`"			;E	`
	.BYTE	$00			;F

					;10
	.BYTE	$00			;0
	.BYTE	$00			;1	LALT
	.BYTE	$00			;2	LSHIFT
	.BYTE	$00			;3
	.BYTE	$00			;4	LCTRL
	.BYTE	"Q"			;5	Q
	.BYTE	"1"			;6	1
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	$00			;9
	.BYTE	"Z"			;A	Z
	.BYTE	"S"			;B	S
	.BYTE	"A"			;C	A
	.BYTE	"W"			;D	W
	.BYTE	"2"			;E	2
	.BYTE	$00			;F

					;20
	.BYTE	$00			;0
	.BYTE	"C"			;1	C
	.BYTE	"X"			;2	X
	.BYTE	"D"			;3	D
	.BYTE	"E"			;4	E
	.BYTE	"4"			;5	4
	.BYTE	"3"			;6	3
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	" "			;9	SPACE
	.BYTE	"V"			;A	V
	.BYTE	"F"			;B	F
	.BYTE	"T"			;C	T
	.BYTE	"R"			;D	R
	.BYTE	"5"			;E	5
	.BYTE	$00			;F

					;30
	.BYTE	$00			;0
	.BYTE	"N"			;1	N
	.BYTE	"B"			;2	B
	.BYTE	"H"			;3	H
	.BYTE	"G"			;4	G
	.BYTE	"Y"			;5	Y
	.BYTE	"6"			;6	6
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	$00			;9
	.BYTE	"M"			;A	M
	.BYTE	"J"			;B	J
	.BYTE	"U"			;C	U
	.BYTE	"7"			;D	7
	.BYTE	"8"			;E	8
	.BYTE	$00			;F

					;40
	.BYTE	$00			;0
	.BYTE	","			;1	,
	.BYTE	"K"			;2	K
	.BYTE	"I"			;3	I
	.BYTE	"O"			;4	O
	.BYTE	"0"			;5	0
	.BYTE	"9"			;6	9
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	"."			;9	.
	.BYTE	"/"			;A	/
	.BYTE	"L"			;B	L
	.BYTE	";"			;C	;
	.BYTE	"P"			;D	P
	.BYTE	"-"			;E	-
	.BYTE	$00			;F

					;50
	.BYTE	$00			;0
	.BYTE	$00			;1
	.BYTE	"'"			;2	'
	.BYTE	$00			;3
	.BYTE	"["			;4	[
	.BYTE	"="			;5	=
	.BYTE	$00			;6
	.BYTE	$00			;7
	.BYTE	$00			;8	CAPSLOCK
	.BYTE	$00			;9	RSHIFT
	.BYTE	$12			;A	ENTER
	.BYTE	"]"			;B	]
	.BYTE	$00			;C
	.BYTE	"\"			;D	\
	.BYTE	$00			;E
	.BYTE	$00			;F

					;60
	.BYTE	$00			;0
	.BYTE	$00			;1
	.BYTE	$00			;2
	.BYTE	$00			;3
	.BYTE	$00			;4
	.BYTE	$00			;5
	.BYTE	$08			;6	BACKSPACE
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	"1"			;9	(KEYPAD) 1
	.BYTE	$00			;A
	.BYTE	"4"			;B	(KEYPAD) 4
	.BYTE	"7"			;C	(KEYPAD) 7
	.BYTE	$00			;D
	.BYTE	$00			;E
	.BYTE	$00			;F

					;70
	.BYTE	"0"			;0	(KEYPAD) 0
	.BYTE	"."			;1	(KEYPAD) .
	.BYTE	"2"			;2	(KEYPAD) 2
	.BYTE	"5"			;3	(KEYPAD) 5
	.BYTE	"6"			;4	(KEYPAD) 6
	.BYTE	"8"			;5	(KEYPAD) 8
	.BYTE	$1B			;6	ESC
	.BYTE	$00			;7	NUMLOCK
	.BYTE	$00			;8	F11
	.BYTE	"+"			;9	(KEYPAD) +
	.BYTE	"3"			;A	(KEYPAD) 3
	.BYTE	"-"			;B	(KEYPAD) -
	.BYTE	"*"			;C	(KEYPAD) *
	.BYTE	"9"			;D	(KEYPAD) 9
	.BYTE	$00			;E	SCROLLLOCK
	.BYTE	$00			;F

					;80
	.BYTE	$00			;0
	.BYTE	$00			;1
	.BYTE	$00			;2
	.BYTE	$00			;3	F7

PS2_EXT_TABLE:
					;00
	.BYTE	$00			;0
	.BYTE	$00			;1
	.BYTE	$00			;2
	.BYTE	$00			;3
	.BYTE	$00			;4
	.BYTE	$00			;5
	.BYTE	$00			;6
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	$00			;9
	.BYTE	$00			;A
	.BYTE	$00			;B
	.BYTE	$00			;C
	.BYTE	$00			;D
	.BYTE	$00			;E
	.BYTE	$00			;F

					;10
	.BYTE	$00			;0
	.BYTE	$00			;1	RALT
	.BYTE	$00			;2	PRINTSCREEN
	.BYTE	$00			;3
	.BYTE	$00			;4	RCTRL
	.BYTE	$00			;5
	.BYTE	$00			;6
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	$00			;9
	.BYTE	$00			;A
	.BYTE	$00			;B
	.BYTE	$00			;C
	.BYTE	$00			;D
	.BYTE	$00			;E
	.BYTE	$00			;F	LGUI

					;20
	.BYTE	$00			;0
	.BYTE	$00			;1
	.BYTE	$00			;2
	.BYTE	$00			;3
	.BYTE	$00			;4
	.BYTE	$00			;5
	.BYTE	$00			;6
	.BYTE	$00			;7	RGUI
	.BYTE	$00			;8
	.BYTE	$00			;9
	.BYTE	$00			;A
	.BYTE	$00			;B
	.BYTE	$00			;C
	.BYTE	$00			;D
	.BYTE	$00			;E
	.BYTE	$00			;F

					;30
	.BYTE	$00			;0
	.BYTE	$00			;1
	.BYTE	$00			;2
	.BYTE	$00			;3
	.BYTE	$00			;4
	.BYTE	$00			;5
	.BYTE	$00			;6
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	$00			;9
	.BYTE	$00			;A
	.BYTE	$00			;B
	.BYTE	$00			;C
	.BYTE	$00			;D
	.BYTE	$00			;E
	.BYTE	$00			;F

					;40
	.BYTE	$00			;0
	.BYTE	$00			;1
	.BYTE	$00			;2
	.BYTE	$00			;3
	.BYTE	$00			;4
	.BYTE	$00			;5
	.BYTE	$00			;6
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	$00			;9
	.BYTE	$00			;A
	.BYTE	$00			;B
	.BYTE	$00			;C
	.BYTE	$00			;D
	.BYTE	$00			;E
	.BYTE	$00			;F


					;50
	.BYTE	$00			;0
	.BYTE	$00			;1
	.BYTE	$00			;2
	.BYTE	$00			;3
	.BYTE	$00			;4
	.BYTE	$00			;5
	.BYTE	$00			;6
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	$00			;9
	.BYTE	$00			;A
	.BYTE	$00			;B
	.BYTE	$00			;C
	.BYTE	$00			;D
	.BYTE	$00			;E
	.BYTE	$00			;F

					;60
	.BYTE	$00			;0
	.BYTE	$00			;1
	.BYTE	$00			;2
	.BYTE	$00			;3
	.BYTE	$00			;4
	.BYTE	$00			;5
	.BYTE	$00			;6
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	$00			;9	END
	.BYTE	$00			;A
	.BYTE	$00			;B	LEFT
	.BYTE	$00			;C	HOME
	.BYTE	$00			;D
	.BYTE	$00			;E
	.BYTE	$00			;F

					;70
	.BYTE	$00			;0	INSERT
	.BYTE	$7F			;1	DELETE
	.BYTE	$00			;2	DOWN
	.BYTE	$00			;3
	.BYTE	$00			;4	RIGHT
	.BYTE	$00			;5	UP
	.BYTE	$00			;6
	.BYTE	$00			;7
	.BYTE	$00			;8
	.BYTE	$00			;9
	.BYTE	$00			;A	PAGEDOWN
	.BYTE	$00			;B
	.BYTE	$00			;C	PRINTSCREEN
	.BYTE	$00			;D	PAGEUP
	.BYTE	$00			;E
	.BYTE	$00			;F

					;80
	.BYTE	$00			;0
	.BYTE	$00			;1
	.BYTE	$00			;2
	.BYTE	$00			;3

;-----------------------------------------------------------------------------
; XMSERIAL.S
; XMICRO-SERIAL DRIVER (KEYBOARD ONLY)
; 2020-04-18
;-----------------------------------------------------------------------------

.INCLUDE "instructions.mac"

.IMPORT __XMICRO_SERIAL_START__, __XMICRO_SERIAL_VECTOR__			;LINKER-GENERATED SYSTEM INFO

.EXPORT PS2_GETKEY, PS2_COMMAND, ASCII_NORMAL_TABLE, ASCII_SHIFT_TABLE
.CONSTRUCTOR XMSERIAL_INIT

;ADDRESS CONSTANTS
	PS2_DATA		:= __XMICRO_SERIAL_START__+$10			;PS/2 DATA REGISTER
	XMSERIAL_CSR		:= __XMICRO_SERIAL_START__+$11			;CARD STATUS REGISTER

	PS2_RETRY_LIMIT		= 2						;NUMBER OF COMMAND RETRIES BEFORE ERROR

.SEGMENT "BSS"
	PS2_FLAGS:		.RES 1						;FLAG BITS FOR KEYBOARD STATE - %RPEB0000 (RESEND, PAUSE, EXTENDED, BREAK-CODE)
	PS2_SCANINDEX:		.RES 1						;SCANCODE INDEX (USED FOR COUNTING DOWN PA/BR SCANCODE)

	PS2_KEYBUFFER_SIZE	= 10						;MAXIMUM NUMBER OF BUFFERED KEYCODES
	PS2_KEYBUFFER:		.RES PS2_KEYBUFFER_SIZE				;KEYCODE BUFFER
	PS2_KEYINDEX:		.RES 1						;KEYCODE BUFFER INDEX - NEXT AVAILABLE POSITION

	PS2_CMDBUFFER_SIZE	= 10						;MAXIMUM NUMBER OF BUFFERED COMMAND BYTES
	PS2_CMDBUFFER:		.RES PS2_CMDBUFFER_SIZE				;COMMAND BUFFER
	PS2_CMDINDEX:		.RES 1						;COMMAND BUFFER INDEX - NEXT AVAILABLE POSITION
	PS2_RETRY:		.RES 1						;COMMAND ERROR-RETRY COUNTER

.SEGMENT "ONCE"
;-----------------------------------------------------------------------------
; XMSERIAL_INIT
; INITIALIZE THE CARD AND DRIVER, LOAD INTERRUPT VECTOR
;-----------------------------------------------------------------------------
.PROC XMSERIAL_INIT
	MWA #XMSERIAL_ISR, __XMICRO_SERIAL_VECTOR__				;LOAD INTERRUPT VECTOR WITH XMSERIAL_ISR ADDRESS

	STZ PS2_SCANINDEX
	STZ PS2_KEYINDEX
	STZ PS2_CMDINDEX
	STZ PS2_FLAGS
	LDA #PS2_RETRY_LIMIT
	STA PS2_RETRY

	LDA #$FF								;RESET AND SELF-TEST KEYBOARD HARDWARE
	STA PS2_DATA
	LDA PS2_DATA								;CLEAR DATA REGISTER

	RTS
.ENDPROC

.SEGMENT "CODE"
;-----------------------------------------------------------------------------
; PS2_COMMAND
; ADD A COMMAND OR DATA BYTE TO THE QUEUE
; REQUIRES: A (COMMAND/DATA BYTE)
; CLOBBERS: A,Y
; RETURNS OVERFLOW FLAG INDICATING BUFFER FULL
;-----------------------------------------------------------------------------
.PROC PS2_COMMAND
	LDY PS2_CMDINDEX							;CHECK IF THE NEW COMMAND WILL OVERFLOW THE COMMAND BUFFER
	CPY PS2_CMDBUFFER_SIZE+1
	BCS OVERFLOW

	SEI									;DISABLE INTERRUPTS TO PREVENT BUFFER CORRUPTION
	LDY PS2_CMDINDEX
	STA PS2_CMDBUFFER,Y							;STORE THE BYTE IN THE COMMAND BUFFER
	INY
	STY PS2_CMDINDEX

	CPY #$02								;SEND A COMMAND TO THE KEYBOARD ONLY WHEN THIS IS THE LAST COMMAND IN THE QUEUE
	BCS RETURN
	JSR PS2_SEND
	LDA #PS2_RETRY_LIMIT
	STA PS2_RETRY
RETURN:
	CLI
	CLV									;CLEAR THE OVERFLOW FLAG
	RTS
OVERFLOW:									;BUFFER OVERFLOW ERROR
	BIT #%01000000								;SET THE OVERFLOW FLAG
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; PS2_SEND
; SEND THE NEXT BYTE IN THE COMMAND QUEUE AND RESET THE FLAGS
; (DOES NOT AFFECT THE QUEUE)
; CLOBBERS: A
;-----------------------------------------------------------------------------
.PROC PS2_SEND
	LDA #%00001000								;CHECK THAT NOTHING IS CURRENTLY BEING SENT TO THE KEYBOARD
	BIT XMSERIAL_CSR
	BNE PS2_SEND								;OTHERWISE WAIT FOR THE CURRENT BYTE TO BE SENT.
	@1:
	LDA PS2_CMDBUFFER
	STA PS2_DATA
	STZ PS2_FLAGS								;RESET THE FLAGS
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; PS2_GETKEY
; GET A KEYCODE FROM THE BUFFER
; RETURNS: A - NEXT KEYCODE ($00 INDICATES NO NEW KEYS - Z SET)
; CLOBBERS: A,X,Y
;-----------------------------------------------------------------------------
.PROC PS2_GETKEY
	LDY PS2_KEYINDEX							;CHECK IF THERE IS A KEYCODE IN THE BUFFER. IF NOT, RETURN
	BEQ @3
	SEI									;DISABLE INTERRUPTS TO PREVENT BUFFER CORRUPTION
@1:	LDY PS2_KEYBUFFER							;LOAD THE CURRENT KEYCODE
	LDX #$00
@2:	LDA PS2_KEYBUFFER+1,X							;SHIFT THE BUFFER CONTENTS TO THE NEXT KEYCODE
	STA PS2_KEYBUFFER,X
	INX
	CPX PS2_KEYINDEX
	BNE @2
	DEC PS2_KEYINDEX
	CLI									;ENABLE INTERRUPTS
	TYA
@3:	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; XMSERIAL_ISR
; INTERRUPT SERVICE ROUTINE FOR THE CARD (CURRENTLY PS/2 ONLY)
;-----------------------------------------------------------------------------
.PROC XMSERIAL_ISR
	PUSH_AXY

	LDA #%00010000
	BIT XMSERIAL_CSR							;CHECK FOR PARITY ERROR
	BEQ GOOD_PARITY
	LDA #$FE								;PARITY ERROR - REQUEST A RESEND
	STA PS2_DATA
	LDX #PS2_RETRY_LIMIT
	LDA PS2_DATA								;CLEAR THE PS/2 READ REGISTER
	STX PS2_RETRY								;RESET THE RETRY LIMIT
	LDA #%10000000
	TSB PS2_FLAGS								;SET THE RESEND FLAG
	JMP END_ISR

GOOD_PARITY:
	LDY PS2_DATA								;LOAD THE LATEST BYTE FROM THE KEYBOARD
	CPY #$FE								;RESEND REQUEST
	BNE @1
	JMP CMD_RESEND
@1:	LDA #%10000000
	BIT PS2_FLAGS								;CHECK FLAGS FOR CURRENT STATE
	BPL @2
	TRB PS2_FLAGS								;CURRENT BYTE IS GOOD, RESET THE RESEND FLAG
@2:	BVC STATE_DEFAULT
	JMP STATE_PABR

STATE_DEFAULT:									;DEFAULT STATE - DECIDE WHAT TO DO BASED ON CURRENT BYTE'S VALUE
	@2:	LDA #%10000000							;CURRENT BYTE IS GOOD - RESET THE RESEND FLAG
		TRB PS2_FLAGS
		CPY #$84							;BELOW $84, (NOT A SPECIAL BYTE)
		BCS @3
		JMP CHECK_EXT
	@3:	CPY #$E0							;START OF AN EXTENDED SCANCODE
		BNE @4
		JMP SET_EXT
	@4:	CPY #$F0							;START OF A BREAK CODE
		BNE @5
		JMP SET_BRK
	@5:	CPY #$E1							;START OF A PAUSE/BREAK SCANCODE
		BNE @6
		JMP SET_PABR
	@6:	CPY #$FA							;COMMAND ACKNOWLEDGED
		BNE @7
		JMP CMD_ACK
	@7:	CPY #$EE							;ECHO RESPONSE
		BNE @8
		JMP CMD_ACK
	@8:	CPY #$AA							;KEYBOARD RESET PASSED
		BNE @9
		JMP RESET_PASS
	@9:	CPY #$FC							;KEYBOARD RESET FAILED
		BNE @10
	@10:	CPY #$FC							;KEYBOARD RESET FAILED
		BNE @11
	@11:	JMP END_ISR							;IGNORE OTHER SPECIAL BYTES

	CHECK_EXT:								;CHECK IF IT'S AN EXTENDED SCANCODE
		LDA #%00100000
		BIT PS2_FLAGS
		BNE @EXT_CODE
		LDX PS2_NORMAL_TABLE,Y						;IF IT'S NOT AN EXTENDED CODE, USE THE NORMAL LOOKUP TABLE
		BRA @CHECK_BRK
		@EXT_CODE:							;IF IT'S AN EXTENDED CODE, USE THE EXTENDED LOOKUP TABLE
		LDX PS2_EXT_TABLE,Y
		@CHECK_BRK:							;CONVERT THE SCANCODE TO A KEYCODE
		BEQ @RETURN							;IF THE KEYCODE IS $00 (NULL), IGNORE THE KEY AND RETURN.
		LDY PS2_KEYINDEX
		CPY PS2_KEYBUFFER_SIZE+1					;CHECK IF THE NEW COMMAND WILL OVERFLOW THE KEYCODE BUFFER
		BCS @OVERFLOW
		LDA #%00010000							;CHECK IF IT'S A BREAK CODE
		BIT PS2_FLAGS
		BNE @BRK_CODE
		TXA
		BRA @STORE_KEYCODE
		@BRK_CODE:							;IF IT'S A BREAK CODE, SET THE KEYCODE BREAK BIT
		TXA
		ORA #%10000000
		@STORE_KEYCODE:							;STORE THE KEYCODE IN THE KEY BUFFER AND END THE ISR
		STA PS2_KEYBUFFER,Y
		INY								;INCREMENT THE KEYCODE BUFFER INDEX
		STY PS2_KEYINDEX
		@RETURN:
		STZ PS2_FLAGS
		JMP END_ISR
		@OVERFLOW:							;BUFFER OVERFLOW ERROR - CURRENTLY DOES NOTHING, JUST IGNORES THE KEY.
		BRA @RETURN

	SET_EXT:								;SET THE EXT FLAG
		LDA #%00100000
		TSB PS2_FLAGS
		JMP END_ISR
	SET_BRK:								;SET THE BRK FLAG
		LDA #%00010000
		TSB PS2_FLAGS
		JMP END_ISR
	SET_PABR:								;SET THE PABR FLAG AND SCANCODE INDEX
		LDA #%01000000
		TSB PS2_FLAGS
		MVA #07, PS2_SCANINDEX
		JMP END_ISR

	CMD_ACK:								;COMMAND BYTE ACKNOWLEDGED
		LDA #PS2_RETRY_LIMIT						;SUCCESSFUL COMMAND, RESET THE RETRY COUNTER
		STA PS2_RETRY
		LDA PS2_CMDINDEX						;CHECK IF THERE ARE MORE COMMAND BYTES IN THE QUEUE
		BEQ @RETURN
		LDX #$00							;IF SO, DROP THE CURRENT COMMAND BYTE
		@1:
		LDA PS2_CMDBUFFER+1,X						;SHIFT THE BUFFER CONTENTS TO THE NEXT BYTE
		STA PS2_CMDBUFFER,X
		INX
		CPX PS2_CMDINDEX
		BNE @1
		DEC PS2_CMDINDEX
		BEQ @RETURN
		JSR PS2_SEND
		@RETURN:
		JMP END_ISR

	RESET_PASS:								;KEYBOARD HAS BEEN RESET AND PASSED SELF-TEST
		LDA #$00							;RESET VARIABLES
		STA PS2_SCANINDEX
		STA PS2_KEYINDEX
		STA PS2_CMDINDEX
		STA PS2_FLAGS
		LDA #PS2_RETRY_LIMIT
		STA PS2_RETRY
		JMP END_ISR

CMD_RESEND:									;RESEND THE LAST COMMAND BYTE
		LDA #%10000000
		BIT PS2_FLAGS							;CHECK IF THE LAST COMMAND WAS A RESEND REQUEST
		BPL BUFFER_RESEND
	FE_RESEND:								;RESEND A RESEND-REQUEST COMMAND ($FE)
			LDX PS2_RETRY						;CHECK IF WE'VE HIT THE RETRY LIMIT
			BEQ @ERROR
			LDA #$FE
			STA PS2_DATA
			DEX							;COUNT ANOTHER RETRY ATTEMPT
			STX PS2_RETRY
			JMP END_ISR

		@ERROR:	JSR XMSERIAL_INIT					;KEYBOARD AND HOST ARE UNABLE TO COMMUNICATE PROPERLY - ATTEMPT KEYBOARD RESET.
			JMP END_ISR

	BUFFER_RESEND:								;RESEND THE LAST COMMAND FROM THE COMMAND BUFFER
		LDX PS2_RETRY							;CHECK IF WE'VE HIT THE RETRY LIMIT
		BEQ @ERROR
		JSR PS2_SEND							;IF NOT, SEND THE LAST BYTE AGAIN.
		DEX								;COUNT ANOTHER RETRY ATTEMPT
		STX PS2_RETRY
		JMP END_ISR
		@ERROR:								;COMMAND FAILED - DROP THE LAST COMMAND (CURRENTLY NO ERROR SIGNALLING)
			LDX #PS2_RETRY_LIMIT					;RESET THE RETRY LIMIT
			STX PS2_RETRY
		@1:	LDX #$00						;IF NOT, DROP THE CURRENT COMMAND (INCLUDING DATA BYTES)
		@2:	LDA PS2_CMDBUFFER+1,X					;SHIFT THE BUFFER CONTENTS TO THE NEXT BYTE
			STA PS2_CMDBUFFER,X
			INX
			CPX PS2_CMDINDEX
			BNE @2
			DEC PS2_CMDINDEX
			BEQ @ECHO
			LDA PS2_CMDBUFFER
			BPL @1							;SHIFT THE BUFFER CONTENTS AGAIN IF IT'S NOT A COMMAND BYTE (BIT 7 SET)
			JSR PS2_SEND						;SEND THE NEXT COMMAND IF THERE IS ONE.
			JMP END_ISR
		@ECHO:	LDA #$EE						;SEND AN ECHO COMMAND IF THERE ARE NO OTHER COMMANDS LEFT
			JSR PS2_COMMAND						;THIS MAKES SURE THE KEYBOARD IS NOT STUCK WAITING FOR A DATA BYTE.
			JMP END_ISR

STATE_PABR:									;PABR STATE - IGNORE REMAINING BYTES OF THE PAUSE/BREAK SCANCODE
	DEC PS2_SCANINDEX
	BNE END_ISR
	STZ PS2_FLAGS
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
; KEYCODES ARE A ONE-BYTE CODE INDICATING WHICH PHYSICAL KEY WAS PRESSED
; BIT 7 INDICATES A KEY BREAK
;-----------------------------------------------------------------------------
PS2_NORMAL_TABLE:								;CONVERT NORMAL SCANCODES TO KEYCODES
	.BYTE	0								;00
	.BYTE	120								;01	F9
	.BYTE	0								;02
	.BYTE	116								;03	F5
	.BYTE	114								;04	F3
	.BYTE	112								;05	F1
	.BYTE	113								;06	F2
	.BYTE	123								;07	F12
	.BYTE	0								;08
	.BYTE	121								;09	F10
	.BYTE	119								;0A	F8
	.BYTE	117								;0B	F6
	.BYTE	115								;0C	F4
	.BYTE	16								;0D	TAB
	.BYTE	1								;0E	`
	.BYTE	0								;0F

	.BYTE	0								;10
	.BYTE	60								;11	LALT
	.BYTE	44								;12	LSHIFT
	.BYTE	0								;13
	.BYTE	58								;14	LCTRL
	.BYTE	17								;15	Q
	.BYTE	2								;16	1
	.BYTE	0								;17
	.BYTE	0								;18
	.BYTE	0								;19
	.BYTE	46								;1A	Z
	.BYTE	32								;1B	S
	.BYTE	31								;1C	A
	.BYTE	18								;1D	W
	.BYTE	3								;1E	2
	.BYTE	0								;1F

	.BYTE	0								;20
	.BYTE	48								;21	C
	.BYTE	47								;22	X
	.BYTE	33								;23	D
	.BYTE	19								;24	E
	.BYTE	5								;25	4
	.BYTE	4								;26	3
	.BYTE	0								;27
	.BYTE	0								;28
	.BYTE	61								;29	SPACE
	.BYTE	49								;2A	V
	.BYTE	34								;2B	F
	.BYTE	21								;2C	T
	.BYTE	20								;2D	R
	.BYTE	6								;2E	5
	.BYTE	0								;2F

	.BYTE	0								;30
	.BYTE	51								;31	N
	.BYTE	50								;32	B
	.BYTE	36								;33	H
	.BYTE	35								;34	G
	.BYTE	22								;35	Y
	.BYTE	7								;36	6
	.BYTE	0								;37
	.BYTE	0								;38
	.BYTE	0								;39
	.BYTE	52								;3A	M
	.BYTE	37								;3B	J
	.BYTE	23								;3C	U
	.BYTE	8								;3D	7
	.BYTE	9								;3E	8
	.BYTE	0								;3F

	.BYTE	0								;40
	.BYTE	53								;41	,
	.BYTE	38								;42	K
	.BYTE	24								;43	I
	.BYTE	25								;44	O
	.BYTE	11								;45	0
	.BYTE	10								;46	9
	.BYTE	0								;47
	.BYTE	0								;48
	.BYTE	54								;49	.
	.BYTE	55								;4A	/
	.BYTE	39								;4B	L
	.BYTE	40								;4C	;
	.BYTE	26								;4D	P
	.BYTE	12								;4E	-
	.BYTE	0								;4F

	.BYTE	0								;50
	.BYTE	0								;51
	.BYTE	41								;52	'
	.BYTE	0								;53
	.BYTE	27								;54	[
	.BYTE	13								;55	=
	.BYTE	0								;56
	.BYTE	0								;57
	.BYTE	30								;58	CAPSLOCK
	.BYTE	57								;59	RSHIFT
	.BYTE	43								;5A	ENTER
	.BYTE	28								;5B	]
	.BYTE	0								;5C
	.BYTE	29								;5D	\
	.BYTE	0								;5E
	.BYTE	0								;5F

	.BYTE	0								;60
	.BYTE	0								;61
	.BYTE	0								;62
	.BYTE	0								;63
	.BYTE	0								;64
	.BYTE	0								;65
	.BYTE	15								;66	BACKSPACE
	.BYTE	0								;67
	.BYTE	0								;68
	.BYTE	93								;69	(KEYPAD) 1
	.BYTE	0								;6A
	.BYTE	92								;6B	(KEYPAD) 4
	.BYTE	91								;6C	(KEYPAD) 7
	.BYTE	0								;6D
	.BYTE	0								;6E
	.BYTE	0								;6F

	.BYTE	99								;70	(KEYPAD) 0
	.BYTE	104								;71	(KEYPAD) .
	.BYTE	98								;72	(KEYPAD) 2
	.BYTE	97								;73	(KEYPAD) 5
	.BYTE	102								;74	(KEYPAD) 6
	.BYTE	96								;75	(KEYPAD) 8
	.BYTE	110								;76	ESC
	.BYTE	90								;77	NUMLOCK
	.BYTE	122								;78	F11
	.BYTE	106								;79	(KEYPAD) +
	.BYTE	103								;7A	(KEYPAD) 3
	.BYTE	105								;7B	(KEYPAD) -
	.BYTE	100								;7C	(KEYPAD) *
	.BYTE	101								;7D	(KEYPAD) 9
	.BYTE	125								;7E	SCROLLLOCK
	.BYTE	0								;7F

	.BYTE	0								;80	ERROR
	.BYTE	0								;81
	.BYTE	0								;82
	.BYTE	118								;83	F7

PS2_EXT_TABLE:									;CONVERT EXTENDED SCANCODES TO KEYCODES
	.BYTE	0								;00
	.BYTE	0								;01
	.BYTE	0								;02
	.BYTE	0								;03
	.BYTE	0								;04
	.BYTE	0								;05
	.BYTE	0								;06
	.BYTE	0								;07
	.BYTE	0								;08
	.BYTE	0								;09
	.BYTE	0								;0A
	.BYTE	0								;0B
	.BYTE	0								;0C
	.BYTE	0								;0D
	.BYTE	0								;0E
	.BYTE	0								;0F

	.BYTE	0								;10
	.BYTE	62								;11	RALT
	.BYTE	124								;12	PRINTSCREEN
	.BYTE	0								;13
	.BYTE	64								;14	RCTRL
	.BYTE	0								;15
	.BYTE	0								;16
	.BYTE	0								;17
	.BYTE	0								;18
	.BYTE	0								;19
	.BYTE	0								;1A
	.BYTE	0								;1B
	.BYTE	0								;1C
	.BYTE	0								;1D
	.BYTE	0								;1E
	.BYTE	0								;1F	LGUI

	.BYTE	0								;20
	.BYTE	0								;21
	.BYTE	0								;22
	.BYTE	0								;23
	.BYTE	0								;24
	.BYTE	0								;25
	.BYTE	0								;26
	.BYTE	0								;27	RGUI
	.BYTE	0								;28
	.BYTE	0								;29
	.BYTE	0								;2A
	.BYTE	0								;2B
	.BYTE	0								;2C
	.BYTE	0								;2D
	.BYTE	0								;2E
	.BYTE	0								;2F

	.BYTE	0								;30
	.BYTE	0								;31
	.BYTE	0								;32
	.BYTE	0								;33
	.BYTE	0								;34
	.BYTE	0								;35
	.BYTE	0								;36
	.BYTE	0								;37
	.BYTE	0								;38
	.BYTE	0								;39
	.BYTE	0								;3A
	.BYTE	0								;3B
	.BYTE	0								;3C
	.BYTE	0								;3D
	.BYTE	0								;3E
	.BYTE	0								;3F

	.BYTE	0								;40
	.BYTE	0								;41
	.BYTE	0								;42
	.BYTE	0								;43
	.BYTE	0								;44
	.BYTE	0								;45
	.BYTE	0								;46
	.BYTE	0								;47
	.BYTE	0								;48
	.BYTE	0								;49
	.BYTE	95								;4A	(KEYPAD) /
	.BYTE	0								;4B
	.BYTE	0								;4C
	.BYTE	0								;4D
	.BYTE	0								;4E
	.BYTE	0								;4F

	.BYTE	0								;50
	.BYTE	0								;51
	.BYTE	0								;52
	.BYTE	0								;53
	.BYTE	0								;54
	.BYTE	0								;55
	.BYTE	0								;56
	.BYTE	0								;57
	.BYTE	0								;58
	.BYTE	0								;59
	.BYTE	108								;5A	(KEYPAD) ENTER
	.BYTE	0								;5B
	.BYTE	0								;5C
	.BYTE	0								;5D
	.BYTE	0								;5E
	.BYTE	0								;5F

	.BYTE	0								;60
	.BYTE	0								;61
	.BYTE	0								;62
	.BYTE	0								;63
	.BYTE	0								;64
	.BYTE	0								;65
	.BYTE	0								;66
	.BYTE	0								;67
	.BYTE	0								;68
	.BYTE	81								;69	END
	.BYTE	0								;6A
	.BYTE	79								;6B	LEFT
	.BYTE	80								;6C	HOME
	.BYTE	0								;6D
	.BYTE	0								;6E
	.BYTE	0								;6F

	.BYTE	75								;70	INSERT
	.BYTE	76								;71	DELETE
	.BYTE	84								;72	DOWN
	.BYTE	0								;73
	.BYTE	89								;74	RIGHT
	.BYTE	83								;75	UP
	.BYTE	0								;76
	.BYTE	0								;77
	.BYTE	0								;78
	.BYTE	0								;79
	.BYTE	86								;7A	PAGEDOWN
	.BYTE	0								;7B
	.BYTE	0								;7C	PRINTSCREEN (SECOND CODE)
	.BYTE	85								;7D	PAGEUP
	.BYTE	0								;7E
	.BYTE	0								;7F

	.BYTE	0								;80	ERROR
	.BYTE	0								;81
	.BYTE	0								;82
	.BYTE	0								;83

ASCII_NORMAL_TABLE:								;CONVERT KEYCODES TO ASCII (UNSHIFTED)
	.BYTE	$00								;0	NULL
	.BYTE	"`"								;1	`
	.BYTE	"1"								;2	1
	.BYTE	"2"								;3	2
	.BYTE	"3"								;4	3
	.BYTE	"4"								;5	4
	.BYTE	"5"								;6	5
	.BYTE	"6"								;7	6
	.BYTE	"7"								;8	7
	.BYTE	"8"								;9	8

	.BYTE	"9"								;10	9
	.BYTE	"0"								;11	0
	.BYTE	"-"								;12	-
	.BYTE	"="								;13	=
	.BYTE	$00								;14
	.BYTE	$00								;15	BACKSPACE
	.BYTE	$00								;16	TAB
	.BYTE	"q"								;17	Q
	.BYTE	"w"								;18	W
	.BYTE	"e"								;19	E

	.BYTE	"r"								;20	R
	.BYTE	"t"								;21	T
	.BYTE	"y"								;22	Y
	.BYTE	"u"								;23	U
	.BYTE	"i"								;24	I
	.BYTE	"o"								;25	O
	.BYTE	"p"								;26	P
	.BYTE	"["								;27	[
	.BYTE	"]"								;28	]
	.BYTE	"\"								;29	\

	.BYTE	$00								;30	CAPSLOCK
	.BYTE	"a"								;31	A
	.BYTE	"s"								;32	S
	.BYTE	"d"								;33	D
	.BYTE	"f"								;34	F
	.BYTE	"g"								;35	G
	.BYTE	"h"								;36	H
	.BYTE	"j"								;37	J
	.BYTE	"k"								;38	K
	.BYTE	"l"								;39	L

	.BYTE	";"								;40	;
	.BYTE	"'"								;41	'
	.BYTE	$00								;42
	.BYTE	$00								;43	ENTER
	.BYTE	$00								;44	LSHIFT
	.BYTE	$00								;45
	.BYTE	"z"								;46	Z
	.BYTE	"x"								;47	X
	.BYTE	"c"								;48	C
	.BYTE	"v"								;49	V

	.BYTE	"b"								;50	B
	.BYTE	"n"								;51	N
	.BYTE	"m"								;52	M
	.BYTE	","								;53	,
	.BYTE	"."								;54	.
	.BYTE	"/"								;55	/
	.BYTE	$00								;56
	.BYTE	$00								;57	RSHIFT
	.BYTE	$00								;58	LCTRL
	.BYTE	$00								;59

	.BYTE	$00								;60	LALT
	.BYTE	" "								;61	SPACE
	.BYTE	$00								;62	RALT
	.BYTE	$00								;63
	.BYTE	$00								;64	RCTRL
	.BYTE	$00								;65
	.BYTE	$00								;66
	.BYTE	$00								;67
	.BYTE	$00								;68
	.BYTE	$00								;69

	.BYTE	$00								;70
	.BYTE	$00								;71
	.BYTE	$00								;72
	.BYTE	$00								;73
	.BYTE	$00								;74
	.BYTE	$00								;75	INSERT
	.BYTE	$00								;76	DELETE
	.BYTE	$00								;77
	.BYTE	$00								;78
	.BYTE	$00								;79	LEFT

	.BYTE	$00								;80	HOME
	.BYTE	$00								;81	END
	.BYTE	$00								;82
	.BYTE	$00								;83	UP
	.BYTE	$00								;84	DOWN
	.BYTE	$00								;85	PAGEUP
	.BYTE	$00								;86	PAGEDOWN
	.BYTE	$00								;87
	.BYTE	$00								;88
	.BYTE	$00								;89	RIGHT

	.BYTE	$00								;90	NUMLOCK
	.BYTE	"7"								;91	NUMPAD 7
	.BYTE	"4"								;92	NUMPAD 4
	.BYTE	"1"								;93	NUMPAD 1
	.BYTE	$00								;94
	.BYTE	"/"								;95	NUMPAD /
	.BYTE	"8"								;96	NUMPAD 8
	.BYTE	"5"								;97	NUMPAD 5
	.BYTE	"2"								;98	NUMPAD 2
	.BYTE	"0"								;99	NUMPAD 0

	.BYTE	"*"								;100	NUMPAD *
	.BYTE	"9"								;101	NUMPAD 9
	.BYTE	"6"								;102	NUMPAD 6
	.BYTE	"3"								;103	NUMPAD 3
	.BYTE	"."								;104	NUMPAD .
	.BYTE	"-"								;105	NUMPAD -
	.BYTE	"+"								;106	NUMPAD +
	.BYTE	$00								;107
	.BYTE	$00								;108	NUMPAD ENTER
	.BYTE	$00								;109

	.BYTE	$00								;110	ESC
	.BYTE	$00								;111
	.BYTE	$00								;112	F1
	.BYTE	$00								;113	F2
	.BYTE	$00								;114	F3
	.BYTE	$00								;115	F4
	.BYTE	$00								;116	F5
	.BYTE	$00								;117	F6
	.BYTE	$00								;118	F7
	.BYTE	$00								;119	F8

	.BYTE	$00								;120	F9
	.BYTE	$00								;121	F10
	.BYTE	$00								;122	F11
	.BYTE	$00								;123	F12
	.BYTE	$00								;124	PRINTSCREEN
	.BYTE	$00								;125	SCROLLLOCK
	.BYTE	$00								;126	PAUSE
	.BYTE	$00								;127

ASCII_SHIFT_TABLE:								;CONVERT KEYCODES TO ASCII (SHIFTED)
	.BYTE	$00								;0	NULL
	.BYTE	"~"								;1	`
	.BYTE	"!"								;2	1
	.BYTE	"@"								;3	2
	.BYTE	"#"								;4	3
	.BYTE	"$"								;5	4
	.BYTE	"%"								;6	5
	.BYTE	"^"								;7	6
	.BYTE	"&"								;8	7
	.BYTE	"*"								;9	8

	.BYTE	"("								;10	9
	.BYTE	")"								;11	0
	.BYTE	"_"								;12	-
	.BYTE	"+"								;13	=
	.BYTE	$00								;14
	.BYTE	$00								;15	BACKSPACE
	.BYTE	$00								;16	TAB
	.BYTE	"Q"								;17	Q
	.BYTE	"W"								;18	W
	.BYTE	"E"								;19	E

	.BYTE	"R"								;20	R
	.BYTE	"T"								;21	T
	.BYTE	"Y"								;22	Y
	.BYTE	"U"								;23	U
	.BYTE	"I"								;24	I
	.BYTE	"O"								;25	O
	.BYTE	"P"								;26	P
	.BYTE	"{"								;27	[
	.BYTE	"}"								;28	]
	.BYTE	"|"								;29	\

	.BYTE	$00								;30	CAPSLOCK
	.BYTE	"A"								;31	A
	.BYTE	"S"								;32	S
	.BYTE	"D"								;33	D
	.BYTE	"F"								;34	F
	.BYTE	"G"								;35	G
	.BYTE	"H"								;36	H
	.BYTE	"J"								;37	J
	.BYTE	"K"								;38	K
	.BYTE	"L"								;39	L

	.BYTE	":"								;40	;
	.BYTE	$22								;41	'
	.BYTE	$00								;42
	.BYTE	$00								;43	ENTER
	.BYTE	$00								;44	LSHIFT
	.BYTE	$00								;45
	.BYTE	"Z"								;46	Z
	.BYTE	"X"								;47	X
	.BYTE	"C"								;48	C
	.BYTE	"V"								;49	V

	.BYTE	"B"								;50	B
	.BYTE	"N"								;51	N
	.BYTE	"M"								;52	M
	.BYTE	"<"								;53	,
	.BYTE	">"								;54	.
	.BYTE	"?"								;55	/
	.BYTE	$00								;56
	.BYTE	$00								;57	RSHIFT
	.BYTE	$00								;58	LCTRL
	.BYTE	$00								;59

	.BYTE	$00								;60	LALT
	.BYTE	" "								;61	SPACE
	.BYTE	$00								;62	RALT
	.BYTE	$00								;63
	.BYTE	$00								;64	RCTRL
	.BYTE	$00								;65
	.BYTE	$00								;66
	.BYTE	$00								;67
	.BYTE	$00								;68
	.BYTE	$00								;69

	.BYTE	$00								;70
	.BYTE	$00								;71
	.BYTE	$00								;72
	.BYTE	$00								;73
	.BYTE	$00								;74
	.BYTE	$00								;75	INSERT
	.BYTE	$00								;76	DELETE
	.BYTE	$00								;77
	.BYTE	$00								;78
	.BYTE	$00								;79	LEFT

	.BYTE	$00								;80	HOME
	.BYTE	$00								;81	END
	.BYTE	$00								;82
	.BYTE	$00								;83	UP
	.BYTE	$00								;84	DOWN
	.BYTE	$00								;85	PAGEUP
	.BYTE	$00								;86	PAGEDOWN
	.BYTE	$00								;87
	.BYTE	$00								;88
	.BYTE	$00								;89	RIGHT

	.BYTE	$00								;90	NUMLOCK
	.BYTE	"7"								;91	NUMPAD 7
	.BYTE	"4"								;92	NUMPAD 4
	.BYTE	"1"								;93	NUMPAD 1
	.BYTE	$00								;94
	.BYTE	"/"								;95	NUMPAD /
	.BYTE	"8"								;96	NUMPAD 8
	.BYTE	"5"								;97	NUMPAD 5
	.BYTE	"2"								;98	NUMPAD 2
	.BYTE	"0"								;99	NUMPAD 0

	.BYTE	"*"								;100	NUMPAD *
	.BYTE	"9"								;101	NUMPAD 9
	.BYTE	"6"								;102	NUMPAD 6
	.BYTE	"3"								;103	NUMPAD 3
	.BYTE	"."								;104	NUMPAD .
	.BYTE	"-"								;105	NUMPAD -
	.BYTE	"+"								;106	NUMPAD +
	.BYTE	$00								;107
	.BYTE	$00								;108	NUMPAD ENTER
	.BYTE	$00								;109

	.BYTE	$00								;110	ESC
	.BYTE	$00								;111
	.BYTE	$00								;112	F1
	.BYTE	$00								;113	F2
	.BYTE	$00								;114	F3
	.BYTE	$00								;115	F4
	.BYTE	$00								;116	F5
	.BYTE	$00								;117	F6
	.BYTE	$00								;118	F7
	.BYTE	$00								;119	F8

	.BYTE	$00								;120	F9
	.BYTE	$00								;121	F10
	.BYTE	$00								;122	F11
	.BYTE	$00								;123	F12
	.BYTE	$00								;124	PRINTSCREEN
	.BYTE	$00								;125	SCROLLLOCK
	.BYTE	$00								;126	PAUSE
	.BYTE	$00								;127

;-----------------------------------------------------------------------------
; FAT.S
; FAT16 FILESYSTEM DRIVER
;-----------------------------------------------------------------------------

;SHOULD ERROR OUT IF $FFFF IS REACHED DURING LOAD
;FAT_LOAD SHOULD VALIDATE ALL ACCESSED CLUSTERS, NOT JUST THE STARTING ONES

.INCLUDE "INSTRUCTIONS.MAC"
.INCLUDE "MOVE.MAC"
.INCLUDE "MATH_32.MAC"
.INCLUDE "CFDRIVER.MAC"

.EXPORT FAT_INIT, FAT_FIND, FAT_LOAD, FAT_LOAD_STREAM						;PROCEDURES
.EXPORTZP FILENAME, FILESIZE, FILEDEST, DESTSIZE, FAT_STATUS			;VARIABLES

;LOCAL VARIABLES
.SEGMENT "ZEROPAGE"
	;MANY VARIABLES HERE DO NOT NEED TO BE 4 BYTES LONG, BUT THIS MAKES ARITHMETIC EASIER
	BOOTBLOCK:		.RES 4		;LBA OF THE PARTITION'S FIRST SECTOR
	TMP1:			.RES 4
	TMP2:			.RES 4
	DUMMY:			.RES 4

	BYTESPERSECTOR:		.RES 4
	SECTORSPERCLUSTER:	.RES 4
	RESERVEDSECTORS:	.RES 4
	FATCOPIES:		.RES 4
	ROOTENTRIES:		.RES 4
	SECTORSPERFAT:		.RES 4

	FATSTART:		.RES 4
	ROOTSTART:		.RES 4
	ROOTSIZE:		.RES 4
	DATASTART:		.RES 4
	BYTESPERCLUSTER:	.RES 4

	STARTCLUSTER:		.RES 4
	FILESIZE:		.RES 4
	FILEDEST:		.RES 2
	DESTSIZE:		.RES 2

	CURRENTCLUSTER:		.RES 4
	CURRENTSECTOR:		.RES 4
	REMAININGSECTORS:	.RES 4
	REMAININGBYTES:		.RES 2

	FAT_STATUS:		.RES 1		;STATUS CODE OF THE FAT DRIVER (NORMALLY ZERO)

	FILENAME:		.RES 11		;.ASCIIZ "AUTOEXECBIN"

.SEGMENT "RODATA"
	S_FAT16:		.ASCIIZ "FAT16   "

.SEGMENT "CODE"

;-----------------------------------------------------------------------------
; FAT_INIT
; READS THE FAT16 BOOT BLOCK, COMPUTES AND INITIALIZES VARIABLES
;-----------------------------------------------------------------------------
.PROC FAT_INIT				;ASSUME WE ALREADY HAVE A BASE ADDRESS. FS DETECTION SHOULD BE ROLLED IN HERE.
	JSR FAT_DETECT
	LDA FAT_STATUS
	BEQ FAT_INIT_BEGIN

	RTS

FAT_INIT_BEGIN:
	CF_READ BOOTBLOCK

	;LOAD PARAMETERS FROM BOOT BLOCK
	MWA CF_BUFFER, CF_BUFFERPOINTER		;RESET THE BUFFER POINTER

	LDY #$0B
	LDA (CF_BUFFERPOINTER),Y
	STA BYTESPERSECTOR
	INY ;$0C
	LDA (CF_BUFFERPOINTER),Y
	STA BYTESPERSECTOR+1

	INY ;$0D
	LDA (CF_BUFFERPOINTER),Y
	STA SECTORSPERCLUSTER

	INY ;$0E
	LDA (CF_BUFFERPOINTER),Y
	STA RESERVEDSECTORS
	INY ;$0F
	LDA (CF_BUFFERPOINTER),Y
	STA RESERVEDSECTORS+1

	INY ;$10
	LDA (CF_BUFFERPOINTER),Y
	STA FATCOPIES

	INY ;$11
	LDA (CF_BUFFERPOINTER),Y
	STA ROOTENTRIES
	INY ;$12
	LDA (CF_BUFFERPOINTER),Y
	STA ROOTENTRIES+1

	LDY #$16
	LDA (CF_BUFFERPOINTER),Y
	STA SECTORSPERFAT
	INY ;$17
	LDA (CF_BUFFERPOINTER),Y
	STA SECTORSPERFAT+1

	;COMPUTE POSITION OF FATS
	;FATSTART = BOOTBLOCK + RESERVEDSECTORS
	ADD32 #BOOTBLOCK, #RESERVEDSECTORS, #FATSTART

	;COMPUTE POSITION OF ROOT DIRECTORY
	;ROOTSTART = FATSTART + (SECTORSPERFAT * FATCOPIES)
	MUL32 #SECTORSPERFAT, #FATCOPIES, #ROOTSTART
	ADD32 #FATSTART, #ROOTSTART, #ROOTSTART

	;COMPUTE SIZE OF ROOT DIRECTORY
	;ENTRIES ARE $20 LONG
	;ROOTSIZE = (ROOTENTRIES * $20) / BYTESPERSECTOR
	MDA #$00000020, TMP2
	MUL32 #ROOTENTRIES, #TMP2, #ROOTSIZE
	DIV32 #ROOTSIZE, #BYTESPERSECTOR, #ROOTSIZE, #DUMMY

	MVA #$02, TMP2
	;COMPUTE POSITION OF DATA REGION
	;FIRST TWO FAT ENTRIES AREN'T SPECIAL AND DON'T POINT TO DATA
	;MUST OFFSET THE START OF THE DATA REGION ACCORDINGLY
	;DATASTART = ROOTSTART + ROOTSIZE - (SECTORSPERCLUSTER * $02)
	MUL32 #SECTORSPERCLUSTER, #TMP2, #TMP1
	ADD32 #ROOTSTART, #ROOTSIZE, #DATASTART
	SUB32 #DATASTART, #TMP1, #DATASTART

	;COMPUTE NUMBER OF BYTES PER CLUSTER
	;BYTESPERCLUSTER = SECTORSPERCLUSTER * BYTESPERSECTOR
	MUL32 #SECTORSPERCLUSTER, #BYTESPERSECTOR, #BYTESPERCLUSTER

	;GIVE AN INVALID START CLUSTER UNTIL A FILE IS SELECTED
	MWA #$FFFF, STARTCLUSTER

	LDA #$00
	STA FAT_STATUS		;SET STATUS $00 (OK)

RETURN:	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; FAT_DETECT
; DETECTS PRESENCE OF A FAT16 FILESYSTEM AND RETURNS SECTOR NUMBER
; RETURNS BOOTBLOCK
;-----------------------------------------------------------------------------
.PROC FAT_DETECT
	CF_READ #$00000000		;READ THE FIRST SECTOR ON THE CARD

CHECK_FAT:				;CHECK FOR A FAT16 SUPERBLOCK IN PLACE OF AN MBR
	LDA CF_BUFFER			;LOAD THE BUFFER POINTER WITH OFFSET TO PARTITION TYPE
	CLC
	ADC #$36
	STA CF_BUFFERPOINTER
	LDA CF_BUFFER+1
	ADC #$00
	STA CF_BUFFERPOINTER+1

		LDY #$07
	CHECK_FAT_LOOP:
		LDA (CF_BUFFERPOINTER),Y
		CMP S_FAT16,Y
		BNE NO_FAT
		DEY
		BPL CHECK_FAT_LOOP
		JMP FOUND_FAT

NO_FAT:
	LDX #$04						;LOOP COUNTER
	LDY #$00						;BUFFER POSITION

	LDA CF_BUFFER						;LOAD THE BUFFER POINTER WITH OFFSET TO PARTITION ENTRIES
	CLC
	ADC #$C2
	STA CF_BUFFERPOINTER
	LDA CF_BUFFER+1
	ADC #$01
	STA CF_BUFFERPOINTER+1

CHECK_MBR:							;CHECK THE CURRENT SECTOR FOR A FAT16 ENTRY IN AN MBR.
	LDA (CF_BUFFERPOINTER),Y				;LOAD MBR PARTITION TYPE
	CMP #$04
	BEQ FOUND_FAT_MBR
	CMP #$06
	BEQ FOUND_FAT_MBR
	TYA
	ADD #$10						;MOVE ON TO THE NEXT PARTITION ENTRY
	TAY
	DEX
	BNE CHECK_MBR

	LDA #$10						;RETURN STATUS $10 (FAT16 FILESYSTEM NOT FOUND)
	STA FAT_STATUS
	RTS

FOUND_FAT_MBR:							;A FAT16 PARTITION HAS BEEN FOUND IN AN MBR
	LDA CF_BUFFER						;LOAD THE BUFFER POINTER WITH OFFSET TO PARTITION LBA
	CLC
	ADC #$C6
	STA CF_BUFFERPOINTER
	LDA CF_BUFFER+1
	ADC #$01
	STA CF_BUFFERPOINTER+1
	LDX #$00

	FOUND_FAT_MBR_LOOP:
		LDA (CF_BUFFERPOINTER),Y
		STA BOOTBLOCK,X
		INY
		INX
		CPX #$04
		BNE FOUND_FAT_MBR_LOOP

	LDA #$00
	STA FAT_STATUS		;RETURN STATUS $00 (OK)
	RTS

FOUND_FAT:
	LDA #$00		;STORE THE BOOT BLOCK LOCATION
	STA BOOTBLOCK
	STA BOOTBLOCK+1
	STA BOOTBLOCK+2
	STA BOOTBLOCK+3
	STA FAT_STATUS		;RETURN STATUS $00 (OK)
	RTS

.ENDPROC

;-----------------------------------------------------------------------------
; FAT_VALIDATE_CLUSTER
; CHECKS WHETHER A CLUSTER NUMBER IS VALID ($0002-$FFEF)
; REQUIRES CURRENTCLUSTER
; RETURNS FAT_STATUS
;-----------------------------------------------------------------------------
.PROC FAT_VALIDATE_CLUSTER
	;CHECK WHETHER THE CURRENT CLUSTER IS VALID
	LDA CURRENTCLUSTER+1		;CHECK IF THE HIGH BYTE IS $00 OR $FF
	BEQ VS00
	CMP #$FF
	BNE VALID_CLUSTER
VSFF:	LDA CURRENTCLUSTER		;HIGH BYTE IS $FF, SO CHECK IF THE LOW BYTE IS $F0-$FF
	AND #$F0			;MASK UNNECESSARY BITS
	CMP #$F0
	BNE VALID_CLUSTER
	BRA INVALID_CLUSTER

VS00:	LDA CURRENTCLUSTER		;HIGH BYTE IS $00, SO CHECK IF THE LOW BYTE IS $00 OR $01
	BEQ INVALID_CLUSTER
	CMP #$01
	BNE VALID_CLUSTER

INVALID_CLUSTER:
	LDA #$13
	STA FAT_STATUS			;RETURN STATUS $13 (INVALID START CLUSTER)
	RTS

VALID_CLUSTER:
	LDA #$00
	STA FAT_STATUS
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; FAT_FIND
; FINDS A FILE MATCHING THE NAME IN "FILENAME" WITHIN THE ROOT DIRECTORY
; REQUIRES FILENAME
; RETURNS STARTCLUSTER, FILESIZE, FAT_STATUS
;-----------------------------------------------------------------------------
.PROC FAT_FIND
	MDA ROOTSTART, CF_LBA			;READ THE ROOT DIRECTORY
	LDX ROOTSIZE
	BRA SECTORLOOP

NEXTSECTOR:
	DEX
	BEQ NOT_FOUND
	LDY #$00
	LDA CF_LBA,Y				;INCREMENT THE SECTOR
	CLC
	ADC #$01
	STA CF_LBA,Y
	BCC SECTORLOOP				;SKIP INCREMENTING THE OTHER BYTES IF THERE'S NO CARRY
	INY
L0:	LDA CF_LBA,Y
	ADC #$00
	STA CF_LBA,Y
	INY
	CPY #$04
	BNE L0

SECTORLOOP:
	CF_READ
	MWA CF_BUFFER, CF_BUFFERPOINTER		;RESET THE BUFFER POINTER FOR A NEW SECTOR
	BRA READENTRY

	NEXTENTRY:				;INCREMENT THE BUFFER POINTER TO THE NEXT ENTRY
		LDA CF_BUFFERPOINTER
		ADD #$20
		STA CF_BUFFERPOINTER
		BCC READENTRY			;IF IT HASN'T CARRIED, READ THE NEXT ENTRY
		LDA CF_BUFFERPOINTER+1		;IF IT HAS, CHECK WHETHER WE'RE ALREADY IN THE UPPER PAGE OF THE BUFFER
		CMP CF_BUFFER+1
		BNE NEXTSECTOR			;IF THIS SECTOR IS COMPLETE, MOVE TO THE NEXT.
		ADD #$01
		STA CF_BUFFERPOINTER+1

	READENTRY:
		LDY #$0B			;READ ATTRIBUTES FOR THIS ENTRY
		LDA (CF_BUFFERPOINTER),Y
		AND #%11011110			;MASK BITS WE DON'T CARE ABOUT
		BNE NEXTENTRY			;IGNORE AND LOOP IF THE ENTRY IS NO GOOD
		DEY
		FILENAME_COMPARE:
			LDA (CF_BUFFERPOINTER),Y
			CMP FILENAME,Y
			BNE NEXTENTRY
			DEY
			BPL FILENAME_COMPARE	;IF Y GOES NEGATIVE THEN THE NAME MATCHES.
			BRA FOUND_FILE

NOT_FOUND:
	LDA #$FF				;STORE AN INVALID CLUSTER TO INDICATE FAILURE
	STA STARTCLUSTER
	STA STARTCLUSTER+1

	LDA #$11
	STA FAT_STATUS				;RETURN STATUS $11 (FILE NOT FOUND)
	RTS

FOUND_FILE:
	LDY #$1A				;LOAD THE FILE'S STARTING CLUSTER NUMBER
	LDA (CF_BUFFERPOINTER),Y
	STA STARTCLUSTER
	INY
	LDA (CF_BUFFERPOINTER),Y
	STA STARTCLUSTER+1
	LDA #$00
	STA STARTCLUSTER+2
	STA STARTCLUSTER+3

	LDX #$00
	INY					;LOAD THE FILE SIZE
L1:	LDA (CF_BUFFERPOINTER),Y
	STA FILESIZE,X
	INY
	INX
	CPX #$04
	BNE L1

	LDA #$00
	STA FAT_STATUS				;RETURN STATUS $00 (OK)

	RTS

.ENDPROC


;-----------------------------------------------------------------------------
; FAT_VALIDATE_FILESIZE
; CHECKS WHETHER THE CURRENT FILE'S SIZE IS GREATER THAN THE MAXIMUM SPECIFIED
; REQUIRES FILESIZE, DESTSIZE
; RETURNS FAT_STATUS
;-----------------------------------------------------------------------------
.PROC FAT_VALIDATE_FILESIZE
	LDA FILESIZE+3		;FILESIZE CAN'T BE OVER $FFFF, SO TOP TWO BYTES MUST BE ZERO
	BNE OVERSIZE

	LDA FILESIZE+2
	BNE OVERSIZE

	LDA FILESIZE+1
	CMP DESTSIZE+1
	BCC GOODSIZE		;SIZE IS GOOD IF FILESIZE+1 < DESTSIZE+1
	BEQ L0			;NEED TO COMPARE NEXT BYTE IF THEY ARE EQUAL
	BRA OVERSIZE		;OTHERWISE IT'S OVERSIZE

L0:	LDA FILESIZE+0		;CHECK IF FILESIZE+0 <= DESTSIZE
	CMP DESTSIZE+0
	BEQ GOODSIZE
	BCS OVERSIZE

GOODSIZE:			;FILESIZE <= DESTSIZE
	LDA #00			;SET FAT_STATUS OK
	STA FAT_STATUS
	RTS

OVERSIZE:			;FILESIZE > DESTSIZE
	LDA #$12			;RETURN STATUS $12 (OVERSIZE FILE)
	STA FAT_STATUS
	RTS
.ENDPROC


;-----------------------------------------------------------------------------
; FAT_LOAD
; LOADS THE CURRENTLY SELECTED FILE INTO MEMORY
; REQUIRES STARTCLUSTER, FILESIZE, FILEDEST
;-----------------------------------------------------------------------------
.PROC FAT_LOAD
	JSR FAT_VALIDATE_FILESIZE
	BEQ GOOD_FILESIZE
	RTS

GOOD_FILESIZE:
	MWA STARTCLUSTER, CURRENTCLUSTER
	JSR FAT_VALIDATE_CLUSTER		;CHECK FOR A VALID CLUSTER
	LDA FAT_STATUS
	BEQ VALID_START				;EXIT IF CLUSTER IS INVALID
	RTS

VALID_START:
	DIV32 #FILESIZE, #BYTESPERSECTOR, #REMAININGSECTORS, #REMAININGBYTES	;FIGURE OUT HOW MANY NORMAL SECTORS TO LOAD AND HOW MANY BYTES TO LOAD ON THE FINAL SECTOR

L0:	MUL32 #CURRENTCLUSTER, #SECTORSPERCLUSTER, #CURRENTSECTOR
	ADD32 #CURRENTSECTOR, #DATASTART, #CURRENTSECTOR			;CALCULATE CURRENT CLUSTER'S START SECTOR
	LDX SECTORSPERCLUSTER

	LDA REMAININGSECTORS						;CHECK IF AT LEAST ONE FULL SECTOR REMAINS
	BNE L1
	JMP LASTSECTOR

	L1:	CF_READ CURRENTSECTOR
		MOVE CF_BUFFER, FILEDEST, #$0200

		INC CURRENTSECTOR
		BNE L2
		INC CURRENTSECTOR+1
		BNE L2
		INC CURRENTSECTOR+2
		BNE L2
		INC CURRENTSECTOR+3

	L2:	INC FILEDEST+1
		INC FILEDEST+1
		DEC REMAININGSECTORS		;ONLY USING ONE BYTE BECAUSE MORE THAN $FF SECTORS IS CURRENTLY IMPOSSIBLE
		BNE L3				;EXIT LOOP IF THERE ARE NO MORE FULL SECTORS TO LOAD
		JMP LASTSECTOR

	L3:	DEX
		BNE L1				;LOOP UNTIL THE CLUSTER IS COMPLETE

	NEXTCLUSTER:
	CLC					;MULTIPLY CURRENTCLUSTER BY TWO FOR FAT POSITION
	ROL CURRENTCLUSTER
	ROL CURRENTCLUSTER+1
	ROL CURRENTCLUSTER+2
	ROL CURRENTCLUSTER+3

	DIV32 #CURRENTCLUSTER, #BYTESPERSECTOR, #TMP1, #TMP2
	ADD32 #TMP1, #FATSTART, #TMP1
	;TMP1 = FAT SECTOR
	;TMP2 = CLUSTER OFFSET

	CF_READ TMP1
	MWA CF_BUFFER, CF_BUFFERPOINTER		;RESET THE BUFFER POINTER FOR A NEW SECTOR

	LDA CF_BUFFERPOINTER+1			;LOAD THE BUFFER HIGH OFFSET
	CLC
	ADC TMP2+1
	STA CF_BUFFERPOINTER+1
	LDY TMP2				;LOAD THE BUFFER LOW OFFSET

	LDA (CF_BUFFERPOINTER),Y		;LOAD THE NEW CLUSTER NUMBER
	STA CURRENTCLUSTER
	INY
	LDA (CF_BUFFERPOINTER),Y
	STA CURRENTCLUSTER+1

	JSR FAT_VALIDATE_CLUSTER		;CHECK FOR A VALID CLUSTER
	LDA FAT_STATUS
	BNE RETURN				;EXIT IF CLUSTER IS INVALID
	JMP L0

LASTSECTOR:			;COPY ONLY REMAINING BYTES IN THE LAST SECTOR
	LDA REMAININGBYTES+1	;SKIP THIS SECTOR IF ZERO BYTES REMAIN.
	BNE LS1
	LDA REMAININGBYTES
	BEQ RETURN_OK
LS1:	CF_READ CURRENTSECTOR
	MOVE CF_BUFFER, FILEDEST, REMAININGBYTES

RETURN_OK:
	LDA #$00
	STA FAT_STATUS		;RETURN STATUS $00 (OK)
RETURN:	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; FAT_LOAD_STREAM
; LOADS THE CURRENTLY SELECTED FILE INTO A SINGLE MEMORY ADDRESS
; REQUIRES STARTCLUSTER, FILESIZE, FILEDEST
;-----------------------------------------------------------------------------
.PROC FAT_LOAD_STREAM

	MWA STARTCLUSTER, CURRENTCLUSTER
	JSR FAT_VALIDATE_CLUSTER		;CHECK FOR A VALID CLUSTER
	LDA FAT_STATUS
	BEQ VALID_START				;EXIT IF CLUSTER IS INVALID
	RTS

VALID_START:
	DIV32 #FILESIZE, #BYTESPERSECTOR, #REMAININGSECTORS, #REMAININGBYTES	;FIGURE OUT HOW MANY NORMAL SECTORS TO LOAD AND HOW MANY BYTES TO LOAD ON THE FINAL SECTOR

L0:	MUL32 #CURRENTCLUSTER, #SECTORSPERCLUSTER, #CURRENTSECTOR
	ADD32 #CURRENTSECTOR, #DATASTART, #CURRENTSECTOR			;CALCULATE CURRENT CLUSTER'S START SECTOR
	LDX SECTORSPERCLUSTER

	LDA REMAININGSECTORS						;CHECK IF AT LEAST ONE FULL SECTOR REMAINS
	BNE L1
	JMP LASTSECTOR

	L1:	CF_READ CURRENTSECTOR
		MOVE_STREAM CF_BUFFER, FILEDEST, #$0200

		INC CURRENTSECTOR
		BNE L2
		INC CURRENTSECTOR+1
		BNE L2
		INC CURRENTSECTOR+2
		BNE L2
		INC CURRENTSECTOR+3

	L2:	;INC FILEDEST+1
		;INC FILEDEST+1
		DEC REMAININGSECTORS		;ONLY USING ONE BYTE BECAUSE MORE THAN $FF SECTORS IS CURRENTLY IMPOSSIBLE
		BNE L3				;EXIT LOOP IF THERE ARE NO MORE FULL SECTORS TO LOAD
		JMP LASTSECTOR

	L3:	DEX
		BNE L1				;LOOP UNTIL THE CLUSTER IS COMPLETE

	NEXTCLUSTER:
	CLC					;MULTIPLY CURRENTCLUSTER BY TWO FOR FAT POSITION
	ROL CURRENTCLUSTER
	ROL CURRENTCLUSTER+1
	ROL CURRENTCLUSTER+2
	ROL CURRENTCLUSTER+3

	DIV32 #CURRENTCLUSTER, #BYTESPERSECTOR, #TMP1, #TMP2
	ADD32 #TMP1, #FATSTART, #TMP1
	;TMP1 = FAT SECTOR
	;TMP2 = CLUSTER OFFSET

	CF_READ TMP1
	MWA CF_BUFFER, CF_BUFFERPOINTER		;RESET THE BUFFER POINTER FOR A NEW SECTOR

	LDA CF_BUFFERPOINTER+1			;LOAD THE BUFFER HIGH OFFSET
	CLC
	ADC TMP2+1
	STA CF_BUFFERPOINTER+1
	LDY TMP2				;LOAD THE BUFFER LOW OFFSET

	LDA (CF_BUFFERPOINTER),Y		;LOAD THE NEW CLUSTER NUMBER
	STA CURRENTCLUSTER
	INY
	LDA (CF_BUFFERPOINTER),Y
	STA CURRENTCLUSTER+1

	JSR FAT_VALIDATE_CLUSTER		;CHECK FOR A VALID CLUSTER
	LDA FAT_STATUS
	BNE RETURN				;EXIT IF CLUSTER IS INVALID
	JMP L0

LASTSECTOR:			;COPY ONLY REMAINING BYTES IN THE LAST SECTOR
	LDA REMAININGBYTES+1	;SKIP THIS SECTOR IF ZERO BYTES REMAIN.
	BNE LS1
	LDA REMAININGBYTES
	BEQ RETURN_OK
LS1:	CF_READ CURRENTSECTOR
	MOVE_STREAM CF_BUFFER, FILEDEST, REMAININGBYTES

RETURN_OK:
	LDA #$00
	STA FAT_STATUS		;RETURN STATUS $00 (OK)
RETURN:	RTS
.ENDPROC

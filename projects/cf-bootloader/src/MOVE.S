;-----------------------------------------------------------------------------
; MOVE.S
; BLOCK MEMORY MOVE PROCEDURES
; ADAPTED FROM http://www.6502.org/source/general/memory_move.html
; 2018-04-20
;-----------------------------------------------------------------------------

.INCLUDE "INSTRUCTIONS.MAC"

.EXPORT MOVEDOWN, ROM_MOVEDOWN, ZERO_FILL
.EXPORTZP MOVE_FROM, MOVE_TO, MOVE_SIZE

.SEGMENT "ZEROPAGE"
	MOVE_FROM:	.RES 2
	MOVE_TO:	.RES 2
	MOVE_SIZE:	.RES 2

.SEGMENT "LOWCODE"

;-----------------------------------------------------------------------------
; MOVEDOWN
; COPIES A BLOCK OF MEMORY STARTING AT THE LOWEST ADDRESS
; *CAN'T BE USED ON OVERLAPPING BLOCKS WHERE THE DESTINATION IS HIGHER*
;
; MOVE_FROM = source start address
; MOVE_TO = destination start address
; MOVE_SIZE = number of bytes to move
;-----------------------------------------------------------------------------
.PROC MOVEDOWN
	PUSH_AXY
	LDY #00
	LDX MOVE_SIZE+1
	BEQ MD2
MD1:	LDA (MOVE_FROM),Y ; move a page at a time
	STA (MOVE_TO),Y
	INY
	BNE MD1
	INC MOVE_FROM+1
	INC MOVE_TO+1
	DEX
	BNE MD1
MD2:	LDX MOVE_SIZE
	BEQ MD4
MD3:	LDA (MOVE_FROM),Y ; move the remaining bytes
	STA (MOVE_TO),Y
	INY
	DEX
	BNE MD3
MD4:	PULL_AXY
	RTS
.ENDPROC


.SEGMENT "CODE"

;-----------------------------------------------------------------------------
; ROM_MOVEDOWN
; COPIES A BLOCK OF MEMORY STARTING AT THE LOWEST ADDRESS (CODE LIVES IN ROM)
; *CAN'T BE USED ON OVERLAPPING BLOCKS WHERE THE DESTINATION IS HIGHER*
;
; MOVE_FROM = source start address
; MOVE_TO = destination start address
; MOVE_SIZE = number of bytes to move
;-----------------------------------------------------------------------------
.PROC ROM_MOVEDOWN
	PUSH_AXY
	LDY #00
	LDX MOVE_SIZE+1
	BEQ MD2
MD1:	LDA (MOVE_FROM),Y ; move a page at a time
	STA (MOVE_TO),Y
	INY
	BNE MD1
	INC MOVE_FROM+1
	INC MOVE_TO+1
	DEX
	BNE MD1
MD2:	LDX MOVE_SIZE
	BEQ MD4
MD3:	LDA (MOVE_FROM),Y ; move the remaining bytes
	STA (MOVE_TO),Y
	INY
	DEX
	BNE MD3
MD4:	PULL_AXY
	RTS
.ENDPROC

;-----------------------------------------------------------------------------
; ZEROFILL
; COPIES ALL ZEROS TO SPECIFIED RANGE
; MOVE_TO = destination start address
; MOVE_SIZE = number of bytes to zero
;-----------------------------------------------------------------------------
.PROC ZERO_FILL
	PUSH_AXY
	LDA #$00
	TAY
	LDX MOVE_SIZE+1
	BEQ L2
L1:	STA (MOVE_TO),Y
	INY
	BNE L1
	INC MOVE_TO+1
	DEX
	BNE L1
L2:	LDX MOVE_SIZE
	BEQ L4
L3:	STA (MOVE_TO),Y
	INY
	DEX
	BNE L3
L4:	PULL_AXY
	RTS
.ENDPROC

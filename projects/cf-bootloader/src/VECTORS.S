; ---------------------------------------------------------------------------
; VECTORS.S
; 6502 hardware vectors and XMICRO-6502 interrupt vector labels
; ---------------------------------------------------------------------------

.IMPORT _INIT
.EXPORT IRQ0, IRQ1, IRQ2, IRQ3, IRQ4, IRQ5, IRQ6, IRQ7, BRK_VECTOR

	IRQ0		:= $0201	;IRQ0-IRQ7 VECTOR ADDRESS LOCATIONS
	IRQ1		:= $0205
	IRQ2		:= $0209
	IRQ3		:= $020D
	IRQ4		:= $0211
	IRQ5		:= $0215
	IRQ6		:= $0219
	IRQ7		:= $021D
	BRK_VECTOR	:= $023C	;BRK CODE ADDRESS

.SEGMENT "VECTORTABLE"

	JMP BRK_VECTOR		;IRQ0
	BRK
	JMP BRK_VECTOR		;IRQ1
	BRK
	JMP BRK_VECTOR		;IRQ2
	BRK
	JMP BRK_VECTOR		;IRQ3
	BRK
	JMP BRK_VECTOR		;IRQ4
	BRK
	JMP BRK_VECTOR		;IRQ5
	BRK
	JMP BRK_VECTOR		;IRQ6
	BRK
	JMP BRK_VECTOR		;IRQ7
	BRK

.SEGMENT  "VECTORS"
	.ADDR	BRK_VECTOR	; NMI VECTOR
	.ADDR	_INIT		; RESET VECTOR
	.ADDR	BRK_VECTOR	; IRQ/BRK VECTOR

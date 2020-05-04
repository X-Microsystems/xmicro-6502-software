; ---------------------------------------------------------------------------
; VECTORS.S
; 6502 hardware vectors and XMICRO-6502 interrupt vector labels
; ---------------------------------------------------------------------------

.IMPORT _INIT									;CODE LABELS

.EXPORT IRQ0, IRQ1, IRQ2, IRQ3, IRQ4, IRQ5, IRQ6, IRQ7, NMI_VECTOR, BRK_VECTOR	;CODE LABELS

	IRQ0		:= $0200	;IRQ0-IRQ7 VECTOR ADDRESS LOCATIONS
	IRQ1		:= $0204
	IRQ2		:= $0208
	IRQ3		:= $020C
	IRQ4		:= $0210
	IRQ5		:= $0214
	IRQ6		:= $0218
	IRQ7		:= $021C
	NMI_VECTOR	:= $0220
	BRK_VECTOR	:= $023C	;BRK CODE ADDRESS


.SEGMENT "VECTORTABLE"

	JMP BRK_VECTOR			;IRQ0
	BRK
	JMP BRK_VECTOR			;IRQ1
	BRK
	JMP BRK_VECTOR			;IRQ2
	BRK
	JMP BRK_VECTOR			;IRQ3
	BRK
	JMP BRK_VECTOR			;IRQ4
	BRK
	JMP BRK_VECTOR			;IRQ5
	BRK
	JMP BRK_VECTOR			;IRQ6
	BRK
	JMP BRK_VECTOR			;IRQ7
	BRK
	JMP BRK_VECTOR			;NMI
	BRK

.SEGMENT "VECTORS"
	.ADDR	NMI_VECTOR		; NMI VECTOR
	.ADDR	_INIT			; RESET VECTOR
	.ADDR	BRK_VECTOR		; IRQ/BRK VECTOR

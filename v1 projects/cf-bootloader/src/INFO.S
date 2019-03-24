; ---------------------------------------------------------------------------
; INFO.S
; ADDS ASSEMBLY INFO TO THE ASSEMBLED ROM FOR IDENTIFICATION
; ---------------------------------------------------------------------------

.SEGMENT "INFO"
	.DWORD .TIME		;ASSEMBLY TIME (LITTLE-ENDIAN UNIX EPOCH)
	.WORD .VERSION		;CA65 ASSEMBLER VERSION

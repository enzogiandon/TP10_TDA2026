		.data
A:		.word	0
		.code
		daddi r1, r0, -5
		nop
		nop
		nop
		bnez r1, fin
		daddi r2, r0, 5
fin:	halt
	
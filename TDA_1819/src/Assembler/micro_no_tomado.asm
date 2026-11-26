		.data
A:		.word	0
		.code
		daddi r1, r0, 1
		nop
		nop
		nop
		beqz r1, fin
		daddi r2, r0, 5
fin:	halt
	
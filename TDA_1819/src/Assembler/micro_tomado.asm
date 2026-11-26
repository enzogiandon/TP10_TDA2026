		.data
A:		.word	0
		.code
		dadd r1, r0, r0
		nop
		nop
		nop
		beqz r1, fin
		daddi r2, r0, 5
fin:	halt
	
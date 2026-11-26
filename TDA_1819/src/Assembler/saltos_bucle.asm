		.data
N:		.word	8
SUMA:	.word	0
		.code
		lw r1, N(r0)
		dadd r2, r0, r0
lazo:	dadd r2, r2, r1
		daddi r1, r1, -1
		bnez r1, lazo
		sw r2, SUMA(r0)
		halt
	
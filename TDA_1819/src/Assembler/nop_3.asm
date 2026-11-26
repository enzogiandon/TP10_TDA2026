		.data
VALOR:	.word	5
		.code
		daddi r1, r0, 2
		nop
		nop
		nop
		sw r1, VALOR(r0)
		halt
	
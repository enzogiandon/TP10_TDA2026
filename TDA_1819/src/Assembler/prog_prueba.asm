		.data
A:		.hword	6153
B:		.hword	3239
SUMA:	.hword	0
MAYOR:	.hword	0
MENOR:	.hword	0
		.code
		lh r1, A(r0)
		lh r2, B(r0)
		slt r3, r1, r2
		bnez r3, SEGUIR
		dadd r3, r1, r0
		dadd r1, r2, r0
		dadd r2, r3, r0
SEGUIR:	dadd r3, r1, r2
		pushh r3
		andi r4, r3, 1
		beqz r4, PAR
IMPAR:	pushh r1
		pushh r2
		lh r6, 0(sp)
		lh r7, 2(sp)		
		jmp ALMAC
PAR:	pushh r2
		pushh r1
		lh r6, 2(sp)
		lh r7, 0(sp)
ALMAC:	lh r5, 4(sp)
		sh r5, SUMA(r0)
		sh r6, MAYOR(r0)
		sh r7, MENOR(r0)
		sh r4, 4(sp)
		beqz r4, PAR2
IMPAR2:	poph r2
		poph r1
		jmp FIN
PAR2:	poph r1
		poph r2
FIN:	poph r3
		halt
	
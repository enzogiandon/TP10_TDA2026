		.data
TABLA:	.word	3, 5, 8, 3, 4, 3, 9, 6
FIN:	.word	32
REF:	.word	3
IGUAL:	.word	0
PARES:	.word	0
IMPAR:	.word	0
		.code
		dadd r1, r0, r0
		lw r9, FIN(r0)
		lw r3, REF(r0)
		dadd r5, r0, r0
		dadd r6, r0, r0
		dadd r8, r0, r0
lazo:	lw r4, TABLA(r1)
		beq r4, r3, igual
		andi r7, r4, 1
		beqz r7, par
		daddi r6, r6, 1
		jmp sigue
par:	daddi r8, r8, 1
		jmp sigue
igual:	daddi r5, r5, 1
sigue:	daddi r1, r1, 4
		bne r9, r1, lazo
		sw r5, IGUAL(r0)
		sw r8, PARES(r0)
		sw r6, IMPAR(r0)
		halt
	
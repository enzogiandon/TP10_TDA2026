# Macro Active-HDL para correr los 6 programas Assembler en secuencia
# Uso desde la consola de Active-HDL (con el workspace C:\My_Designs\TDA_1819\TDA_1819.aws abierto):
#   do "C:/Users/Enzo/Documents/GitHub/TP10_TDA2026/TDA_1819/src/correr_6_tests.do"

transcript to $dsn/src/resultados_6_tests.log
cd $dsn/src

@echo "================================================================"
@echo " [1/6] micro_sin_salto.asm  (Esperado: R1=0, R2=5)"
@echo "================================================================"
asim -GProgName="micro_sin_salto.asm" -GPipelining=true tda_1819.usuario
run 10 us
examine /usuario/DoneCompUser
examine /usuario/DoneCpuUser
examine -dec /usuario/UUT/UUT2/UUT7/R1
examine -dec /usuario/UUT/UUT2/UUT7/R2
endsim

@echo "================================================================"
@echo " [2/6] micro_tomado.asm  (Esperado: R1=0, R2=0)"
@echo "================================================================"
asim -GProgName="micro_tomado.asm" -GPipelining=true tda_1819.usuario
run 10 us
examine /usuario/DoneCompUser
examine /usuario/DoneCpuUser
examine -dec /usuario/UUT/UUT2/UUT7/R1
examine -dec /usuario/UUT/UUT2/UUT7/R2
endsim

@echo "================================================================"
@echo " [3/6] micro_no_tomado.asm  (Esperado: R1=1, R2=5)"
@echo "================================================================"
asim -GProgName="micro_no_tomado.asm" -GPipelining=true tda_1819.usuario
run 10 us
examine /usuario/DoneCompUser
examine /usuario/DoneCpuUser
examine -dec /usuario/UUT/UUT2/UUT7/R1
examine -dec /usuario/UUT/UUT2/UUT7/R2
endsim

@echo "================================================================"
@echo " [4/6] micro_negativo.asm  (Esperado: R1=0xFFFFFFFB (-5), R2=0)"
@echo "================================================================"
asim -GProgName="micro_negativo.asm" -GPipelining=true tda_1819.usuario
run 10 us
examine /usuario/DoneCompUser
examine /usuario/DoneCpuUser
examine -hex /usuario/UUT/UUT2/UUT7/R1
examine -dec /usuario/UUT/UUT2/UUT7/R2
endsim

@echo "================================================================"
@echo " [5/6] saltos_bucle.asm  (Esperado: R1=0, R2=36)"
@echo "================================================================"
asim -GProgName="saltos_bucle.asm" -GPipelining=true tda_1819.usuario
run 30 us
examine /usuario/DoneCompUser
examine /usuario/DoneCpuUser
examine -dec /usuario/UUT/UUT2/UUT7/R1
examine -dec /usuario/UUT/UUT2/UUT7/R2
endsim

@echo "================================================================"
@echo " [6/6] saltos_mixtos.asm  (Esperado: R5=3, R8=3, R6=2)"
@echo "================================================================"
asim -GProgName="saltos_mixtos.asm" -GPipelining=true tda_1819.usuario
run 30 us
examine /usuario/DoneCompUser
examine /usuario/DoneCpuUser
examine -dec /usuario/UUT/UUT2/UUT7/R5
examine -dec /usuario/UUT/UUT2/UUT7/R8
examine -dec /usuario/UUT/UUT2/UUT7/R6
endsim

@echo "================================================================"
@echo " FIN DE LAS 6 PRUEBAS"
@echo "================================================================"
transcript to -off

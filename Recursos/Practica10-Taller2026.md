Taller de Arquitectura

Trabajo Práctico 10

Procesador TDA 1819
1. A continuación, se proponen algunas funcionalidades cuya implementación todavía se
encuentra pendiente en el procesador TDA 1819. Se asignará por sorteo a cada grupo de
alumnos una de dichas funcionalidades a fin de que diseñe y desarrolle en el lenguaje VHDL
el mecanismo necesario para incorporarla a las prestaciones actuales del procesador:
ej1. Implementar las instrucciones de manejo de pila faltantes (ver la tabla 38 del manual).
ej2. Implementar un mecanismo para el manejo de la pila alternativo a aquél actualmente
disponible en el TDA 1819, en el que se use un registro de uso general en vez del registro
SP (Stack Pointer) para desplazarse a través de la pila, tal como se realiza en el MIPS64
(simulador WinMIPS64).
ej3. Modificar las instrucciones de transferencia de control (excepto "jmp", ver la tabla 38 del
manual) para que todas las acciones que actualmente se están llevando a cabo en la etapa
Execute del ciclo de instrucción se ejecuten en la etapa Decode, tal como ocurre en el
MIPS64 (simulador WinMIPS64).
ej4. Incorporar la posibilidad de habilitar la técnica de Adelantamiento o Forwarding para
facilitar la prevención de atascos en el cauce segmentado del TDA 1819 por dependencias
de datos de tipo RAW. Se plantean los siguientes escenarios posibles de ejecución para
implementar esta técnica, cada uno de los cuales se sorteará y asignará individualmente y
por separado entre los grupos de alumnos (ver el repertorio de instrucciones en la tabla 38
del manual):
4a. Una instrucción aritmético-lógica realiza una operación aritmético-lógica en la ALU
durante la etapa Execute cuyo resultado obtenido es requerido por otra instrucción
aritmético-lógica como operando para poder realizar su propia operación aritmético-lógica
en la ALU durante la etapa Execute.
4b. Una instrucción aritmético-lógica realiza una operación aritmético-lógica en la ALU
durante la etapa Execute cuyo resultado obtenido es requerido por una instrucción de
transferencia de datos "store" para almacenarlo en la sección de datos de la memoria
principal durante la etapa Memory Access.
4c. Una instrucción de transferencia de datos "load" realiza una operación de lectura en la
sección de datos de la memoria principal durante la etapa Memory Access cuyo valor
leído es requerido por una instrucción aritmético-lógica como operando para poder
realizar una operación aritmético-lógica en la ALU durante la etapa Execute.
4d. Una instrucción de transferencia de datos "load" realiza una operación de lectura en la
sección de datos de la memoria principal durante la etapa Memory Access cuyo valor
leído es requerido por una instrucción de transferencia de datos "store" para almacenarlo
en la sección de datos de la memoria principal durante la etapa Memory Access.
2. Luego, habrán de escribirse al menos dos programas de prueba en el lenguaje Assembly tales
que hagan uso de la nueva funcionalidad asignada para su implementación en el TDA 1819
en el primer ejercicio de este trabajo y permitan establecer un claro contraste con el estado
original del procesador previo a la incorporación de la funcionalidad. Los programas pueden
desarrollarse en un principio sin ningún tipo de restricción alguna, quedando entonces su
implementación librada al ingenio de los alumnos, siempre y cuando se incluya posteriormente
en el informe una documentación detallada que describa y justifique apropiadamente cada
Taller 2026 1/2

Taller de Arquitectura

programa implementado y la manera en la cual cada uno de ellos permite alcanzar los
objetivos planteados en esta consigna (por ejemplo, podría plantearse un programa que no
utilice la nueva funcionalidad y otro que sí lo haga, a fin de compararlos entre sí).
3. Una vez simulada la ejecución en el TDA 1819 de los programas desarrollados en el ejercicio
precedente, resolver las consignas finales seguidamente definidas:
a. Determinar los tiempos de ejecución de los programas con la segmentación del cauce del
procesador habilitada y deshabilitada (activando y desactivando también el Forwarding si
fue asignado alguno de los escenarios de la funcionalidad propuesta en el ejercicio “4” del
punto 1.). Deben distinguirse también los tiempos de ensamblaje de aquéllos
correspondientes a las ejecuciones propiamente dichas de los programas en el
procesador.
b. Describir los aspectos más relevantes del flujo de la ejecución de los programas, en
particular, el ciclo de instrucción de cada una de las instrucciones de los mismos, e
identificar las etapas de cada ciclo en las que se lee, escribe o procesa información (datos
o instrucciones) en los distintos componentes de la computadora: secciones de la memoria
principal (datos, instrucciones o pila), unidad aritmético-lógica (ALU) y registros de uso
general y particular de la CPU.
El objetivo aquí es demostrar minuciosamente que los programas desarrollados utilizan
efectivamente la nueva funcionalidad implementada en el TDA 1819.
4. La entrega del presente trabajo práctico involucra los siguientes requerimientos:
a. Un informe detallado que contenga toda la información que juzgue pertinente para la
resolución de los problemas aquí planteados. Más precisamente, se sugiere incluir
explicaciones pormenorizadas para los primeros dos puntos junto con las soluciones de la
tercera consigna con sus debidas justificaciones.
b. Los archivos VHDL (extensión “.vhd”) del proyecto “TDA_1819” actualizados con todos los
cambios que resultaron necesarios para implementar el mecanismo solicitado en el punto
1. No se requiere enviar el espacio de trabajo o workspace completo, alcanza con
especificar en el informe los nombres de los ficheros modificados junto con las rutas en las
cuales deberán ser ubicados dentro del proyecto original para la correcta simulación del
procesador.
c. Los nuevos programas desarrollados en el lenguaje Assembly tal como se especifica en el
punto 2 (extensión “.asm”). Se recomienda asimismo en este caso incluir en el informe la
ruta de los mencionados programas en el proyecto “TDA_1819” para evitar cualquier
inconveniente que pudiera presentarse durante el ensamblaje y/o la ejecución de los
mismos.
d. Una presentación con diapositivas que deberá estar basada en el informe cuya redacción
se solicita en el inciso “a” del presente punto 4. La misma habrá de ser expuesta por cada
grupo de alumnos en una defensa oral del trabajo realizado a partir de la entrega.

Fecha límite de entrega por mensajería de IDEAS:

viernes 27 de noviembre de 2026
a las 11:59:59 hs. (mediodía)

Taller 2026 2/2


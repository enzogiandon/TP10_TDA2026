# Trabajo Práctico 10 — Procesador TDA 1819
**Materia:** Taller de Arquitectura (Ciclo Lectivo 2026)  
**Institución:** Facultad de Ingeniería, Universidad Nacional de La Plata (UNLP)  
**Alumno:** Enzo Giandon  

---

## 1. Descripción General del Proyecto

Este repositorio contiene el desarrollo del **Trabajo Práctico 10**, centrado en el estudio, modificación y simulación del procesador didáctico **TDA 1819**, una computadora de 32 bits con cauce segmentado desarrollada en lenguaje VHDL para la enseñanza de arquitectura de computadoras.

---

## 2. Documentación de Cátedra y Bibliografía de Referencia

Dentro del directorio [`Recursos/`](Recursos/) se preserva el material didáctico y bibliográfico provisto por la cátedra:

- **Manual y Libro de Referencia:**
  - [`Recursos/document.pdf`](Recursos/document.pdf): *"TDA 1819: Descripción y simulación de una computadora de 32 bits"* (Autor: Facundo Ricardo Scorza, UNLP).  
    Constituye la memoria descriptiva oficial del procesador. Se destacan los siguientes capítulos:
    - **Capítulo 3.1.2 & 3.1.3 (pág. 54–65):** Directivas, repertorio de instrucciones (Tabla 38), códigos de operación y formatos de instrucción.
    - **Capítulo 3.1.6 (pág. 99–119):** Ciclo de instrucción y segmentación del cauce de 5 etapas:
      1. **Fetch (IF):** Búsqueda de instrucción en memoria y actualización provisional del puntero de instrucción ($IP$).
      2. **Decode (ID):** Decodificación del código de operación, lectura de operandos del banco de registros y detección de atascos.
      3. **Execute (EX):** Operaciones en la ALU de enteros o en la FPU de punto flotante.
      4. **Memory Access (MA):** Lectura y escritura en la memoria de datos o en la sección de pila.
      5. **Writeback (WB):** Escritura del resultado en el registro destino del banco de registros.
    - **Capítulo 3.1.8.5 (pág. 109–113):** Riesgos de control y atascos en el cauce segmentado. Explica detalladamente por qué el procesador original resuelve las bifurcaciones condicionales en Execute (retrasando la decisión 2 ciclos).

- **Guía de Trabajos Prácticos:**
  - [`Recursos/Practica10-Taller2026.pdf`](Recursos/Practica10-Taller2026.pdf) (versión textual en [`Practica10-Taller2026.md`](Recursos/Practica10-Taller2026.md)): Enunciado oficial de la Práctica 10 para la cursada 2026.

---

## 3. Ejercicios Propuestos en la Consigna (Taller 2026)

La consigna del TP10 propone cuatro funcionalidades de mejora pendientes en el procesador original:

1. **Ejercicio 1 — Instrucciones de manejo de pila faltantes:**  
   Implementar las instrucciones de pila no completadas en el modelo base (`pushw`, `popw`, `pushfl`, `popfl`, `pushfp`, `popfp`, `pushra`, `popra`).
2. **Ejercicio 2 — Manejo de pila alternativo con registros de uso general:**  
   Implementar un esquema de desplazamiento de pila utilizando registros generales en lugar del registro dedicado $SP$, tal como opera el simulador WinMIPS64.
3. **Ejercicio 3 — Transferencia de control resuelta en Decode (ASIGNADO):**  
   Modificar las instrucciones de transferencia de control (excepto `jmp`, que ya opera en Decode) para que todas las acciones de evaluación de condición y actualización del $IP$ actualmente efectuadas en Execute se resuelvan directamente en Decode.
4. **Ejercicio 4 — Mecanismo de Adelantamiento (Forwarding):**  
   Implementar técnicas de *bypass* para mitigar atascos por dependencias RAW en cuatro escenarios sorteados:
   - **4a:** ALU $\to$ ALU (Execute a Execute).
   - **4b:** ALU $\to$ STORE (Execute a Memory Access).
   - **4c:** LOAD $\to$ ALU (Memory Access a Execute).
   - **4d:** LOAD $\to$ STORE (Memory Access a Memory Access).

---

## 4. Detalle del Ejercicio Asignado: Ejercicio 3 (Decode Branching)

### 4.1. Fundamentación Teórica
En la microarquitectura original del TDA 1819:
- Los saltos condicionales (`beq`, `bne`, `beqz`, `bnez`, `bfpt`, `bfpf`) leen los operandos en Decode, pero envían los datos a la ALU para realizar la resta o comprobación en la etapa **Execute**.
- Esto obliga al procesador a activar la señal `StallBrEX`, deteniendo las etapas Fetch y Decode durante **2 ciclos de reloj** (burbujas en el cauce) hasta que la ALU evalúa el salto y actualiza el $IP$.

Siguiendo el principio de diseño de procesadores RISC (MIPS64 / WinMIPS64):
- Se dota a la etapa **Decode** de hardware combinacional de comparación directa (igualdad, diferencia o detección de cero sobre el bus de lectura de registros) y lectura de flags.
- Si el salto es **tomado (*taken*)**:
  - Se escribe la dirección de destino en el $IP$ de forma inmediata (`EnableRegIDIP <= '1'`).
  - La penalización por salto se reduce de 2 ciclos a **1 solo ciclo de parada** (`StallBrID <= '1'`), logrando un ahorro sistemático de 1 ciclo por cada iteración de bucle o bifurcación efectiva.
- Si el salto es **no tomado (*not taken*)**:
  - El $IP$ no se altera y la instrucción subsiguiente continúa avanzando linealmente, con **0 ciclos de penalización**.

### 4.2. Alcance de Instrucciones Modificadas
Se adaptan las 6 instrucciones condicionales completas del repertorio (Tabla 38):
- **Enteros:** `beq` ($rf = rg$), `bne` ($rf \ne rg$), `beqz` ($rf = 0$), `bnez` ($rf \ne 0$).
- **Punto Flotante:** `bfpt` ($FP\_FLAG = 1$), `bfpf` ($FP\_FLAG = 0$).
- *(La instrucción `jmp` se mantiene inalterada puesto que en el diseño base ya saltaba en Decode).*

---

## 5. Estructura de Directorios

```text
TP10/
├── README.md                  # Este documento
├── simular_tp10.sh            # Script automatizado de compilación y simulación con GHDL
├── Recursos/                  # Archivos y fuentes originales entregados por la cátedra
│   ├── Practica10-Taller2026.pdf
│   ├── Practica10-Taller2026.md
│   ├── document.pdf           # Libro/manual de referencia del TDA 1819
│   └── TDA-1819/              # Proyecto original intacto (Active-HDL)
└── TDA_1819/                  # Proyecto de trabajo con las modificaciones implementadas
    ├── compilation.order
    └── src/
        ├── Packages/          # Paquetes de constantes, tipos y funciones de la CPU
        ├── Assembler/         # Programas de prueba en Assembler (.asm)
        └── Usuario/           # Arquitectura estructural y etapas del procesador
            ├── usuario.vhd    # Banco de pruebas (Top-level Entity)
            └── PC/
                ├── 1. Ensamblador/ensamblador.vhd
                └── 2. CPU/
                    ├── 2. Etapas/
                    │   ├── 1. Fetch/fetch.vhd
                    │   ├── 2. Decode/decode.vhd       <-- Modificado (Punto 1)
                    │   └── 3. Execute/
                    │       ├── 1. ALU/execute_alu.vhd
                    │       └── execute.vhd
                    └── ...
```

---

## 6. Flujo de Simulación con GHDL y GTKWave

Para simular el procesador en Linux se provee el script [`simular_tp10.sh`](simular_tp10.sh):

```bash
# Simular con cauce segmentado (por defecto):
./simular_tp10.sh prog_prueba.asm

# Simular sin segmentación (Pipelining = false):
./simular_tp10.sh prog_prueba.asm -np

# Simular y abrir visualizador de ondas GTKWave:
./simular_tp10.sh prog_prueba.asm -w

# Simular sobre la versión original (Recursos/) para contrastar:
./simular_tp10.sh prog_prueba.asm -o
```

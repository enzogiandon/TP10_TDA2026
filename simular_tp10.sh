#!/usr/bin/env bash
# ==============================================================================
# Script de simulación automatizada con GHDL para el TP10 (TDA 1819)
# Materia: Taller de Arquitectura — FI-UNLP
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/TDA_1819"
ORIG_DIR="$SCRIPT_DIR/Recursos/TDA-1819/My_Designs/TDA_1819/TDA_1819"

mostrar_ayuda() {
    echo -e "${BOLD}Uso:${NC} $0 [OPCIONES] [PROGRAMA_ASM]"
    echo ""
    echo -e "${BOLD}Argumentos:${NC}"
    echo "  [PROGRAMA_ASM]             Nombre del archivo .asm en Assembler/ (por defecto: prog_prueba.asm)"
    echo ""
    echo -e "${BOLD}Opciones:${NC}"
    echo "  -w, -g, --wave, --gtkwave  Genera y abre formas de onda en GTKWave al terminar."
    echo "  -np, --no-pipeline         Ejecuta la simulación sin segmentación (Pipelining=false)."
    echo "  -p, --pipeline             Ejecuta la simulación con segmentación (Pipelining=true, por defecto)."
    echo "  -s, --stop-time=<tiempo>   Tiempo de parada de la simulación (ej: 5us, 10us, por defecto: 10us)."
    echo "  -o, --original             Simula sobre la versión original del TDA 1819 (en Recursos/)."
    echo "  -c, --clean                Limpia archivos generados de compilación (.cf, binarios, .ghw)."
    echo "  -h, --help                 Muestra este mensaje de ayuda."
    echo ""
    echo -e "${BOLD}Ejemplos:${NC}"
    echo "  $0 prog_prueba.asm"
    echo "  $0 prog_prueba.asm -w"
    echo "  $0 prog_prueba.asm -np"
    echo "  $0 prog_prueba.asm -o      # Compara contra la versión original"
    exit 0
}

OPEN_GTKWAVE=false
PIPELINING=true
STOP_TIME="10us"
USE_ORIGINAL=false
CLEAN_ONLY=false
ASM_PROG="prog_prueba.asm"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            mostrar_ayuda
            ;;
        -w|-g|--wave|--gtkwave)
            OPEN_GTKWAVE=true
            shift
            ;;
        -np|--no-pipeline)
            PIPELINING=false
            shift
            ;;
        -p|--pipeline)
            PIPELINING=true
            shift
            ;;
        -s|--stop-time)
            STOP_TIME="$2"
            shift 2
            ;;
        --stop-time=*)
            STOP_TIME="${1#*=}"
            shift
            ;;
        -o|--original)
            USE_ORIGINAL=true
            shift
            ;;
        -c|--clean)
            CLEAN_ONLY=true
            shift
            ;;
        -*)
            echo -e "${RED}Opción no reconocida:${NC} $1"
            mostrar_ayuda
            ;;
        *)
            ASM_PROG="$1"
            shift
            ;;
    esac
done

TARGET_DIR="$WORK_DIR"
if [ "$USE_ORIGINAL" = true ]; then
    TARGET_DIR="$ORIG_DIR"
fi

cd "$TARGET_DIR"

if [ "$CLEAN_ONLY" = true ]; then
    echo -e "${YELLOW}Limpiando archivos de simulación en $TARGET_DIR...${NC}"
    rm -f *.cf *.o usuario *.ghw
    echo -e "${GREEN}Limpieza finalizada.${NC}"
    exit 0
fi

# Asegurar enlace simbólico a la carpeta Assembler
[ -e Assembler ] || ln -s src/Assembler Assembler

echo -e "${BLUE}${BOLD}================================================================${NC}"
echo -e "${BLUE}${BOLD} Simulación TDA 1819 — GHDL (TP10)                              ${NC}"
echo -e "${BLUE}${BOLD}================================================================${NC}"
echo -e "  ${BOLD}Versión:${NC}     $([ "$USE_ORIGINAL" = true ] && echo "${YELLOW}Original (Recursos)${NC}" || echo "${GREEN}Modificada (Decode Branching)${NC}")"
echo -e "  ${BOLD}Programa:${NC}    $ASM_PROG"
echo -e "  ${BOLD}Pipeline:${NC}    $([ "$PIPELINING" = true ] && echo "Habilitado (true)" || echo "Deshabilitado (false)")"
echo -e "  ${BOLD}Stop time:${NC}   $STOP_TIME"
echo ""

# Compilación si el ejecutable no existe o si los fuentes son más nuevos
if [ ! -f "usuario" ]; then
    echo -e "${YELLOW}Compilando librerías y componentes del procesador con GHDL...${NC}"
    ghdl -a --std=08 --work=ieee_proposed /usr/lib/ghdl/src/ieee2008/float_pkg.vhdl 2>/dev/null || true

    PACKAGES=(
        "src/Packages/const_reloj.vhd"
        "src/Packages/tipos_cpu.vhd"
        "src/Packages/tipos_memoria.vhd"
        "src/Packages/const_memoria.vhd"
        "src/Packages/const_registros.vhd"
        "src/Packages/const_flags.vhd"
        "src/Packages/const_buses.vhd"
        "src/Packages/const_cpu.vhd"
        "src/Packages/tipos_ensamblador.vhd"
        "src/Packages/repert_cpu.vhd"
        "src/Packages/tipos_ascii.vhd"
        "src/Packages/const_ascii.vhd"
        "src/Packages/func_ensamblador.vhd"
        "src/Packages/const_ensamblador.vhd"
    )

    COMPONENTS=(
        "src/Usuario/PC/2. CPU/6. Reloj/reloj.vhd"
        "src/Usuario/PC/2. CPU/7. Registros/registros.vhd"
        "src/Usuario/PC/2. CPU/5. CPU_Admin/cpu_admin.vhd"
        "src/Usuario/PC/2. CPU/3. Pipeline_Registros/pipeline_registros.vhd"
        "src/Usuario/PC/2. CPU/4. Atascos/1. Estructurales/str_detector.vhd"
        "src/Usuario/PC/2. CPU/4. Atascos/2. Datos/raw_waw_detector.vhd"
        "src/Usuario/PC/2. CPU/4. Atascos/atascos.vhd"
        "src/Usuario/PC/2. CPU/1. UI/1. Máquina de Estados/states_machine.vhd"
        "src/Usuario/PC/2. CPU/1. UI/2. Registros FP/registros_fp.vhd"
        "src/Usuario/PC/2. CPU/1. UI/ui.vhd"
        "src/Usuario/PC/2. CPU/2. Etapas/1. Fetch/fetch.vhd"
        "src/Usuario/PC/2. CPU/2. Etapas/2. Decode/decode.vhd"
        "src/Usuario/PC/2. CPU/2. Etapas/3. Execute/1. ALU/execute_alu.vhd"
        "src/Usuario/PC/2. CPU/2. Etapas/3. Execute/2. FPU/execute_fpu.vhd"
        "src/Usuario/PC/2. CPU/2. Etapas/3. Execute/execute.vhd"
        "src/Usuario/PC/2. CPU/2. Etapas/4. Memory Access/memory_access.vhd"
        "src/Usuario/PC/2. CPU/2. Etapas/5. Writeback/writeback.vhd"
        "src/Usuario/PC/2. CPU/2. Etapas/etapas.vhd"
        "src/Usuario/PC/2. CPU/cpu.vhd"
        "src/Usuario/PC/3. Buses_Admin/buses_admin.vhd"
        "src/Usuario/PC/4. Memoria/memoria.vhd"
        "src/Usuario/PC/1. Ensamblador/ensamblador.vhd"
        "src/Usuario/PC/pc.vhd"
        "src/Usuario/usuario.vhd"
    )

    for src in "${PACKAGES[@]}" "${COMPONENTS[@]}"; do
        ghdl -a --std=08 --work=tda_1819 "$src"
    done

    echo -e "${YELLOW}Elaborando entidad superior 'usuario'...${NC}"
    ghdl -e --std=08 --work=tda_1819 usuario
    echo -e "${GREEN}Compilación exitosa.${NC}"
    echo ""
fi

# Configurar ejecución
GHW_FILE="sim_tp10.ghw"
CMD=("./usuario" "-gProgName=$ASM_PROG" "-gPipelining=$PIPELINING" "--stop-time=$STOP_TIME")
if [ "$OPEN_GTKWAVE" = true ]; then
    CMD+=("--wave=$GHW_FILE")
fi

echo -e "${GREEN}Iniciando simulación...${NC}"
"${CMD[@]}"

if [ "$OPEN_GTKWAVE" = true ] && [ -f "$GHW_FILE" ]; then
    echo -e "${BLUE}Abriendo GTKWave...${NC}"
    gtkwave "$GHW_FILE" &
fi

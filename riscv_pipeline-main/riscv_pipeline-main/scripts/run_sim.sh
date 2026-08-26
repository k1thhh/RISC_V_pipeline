#!/usr/bin/env bash
# run_sim.sh — compile and run RTL simulations with Icarus Verilog
#
# Usage:
#   scripts/run_sim.sh unit                                  # run all unit tests
#   scripts/run_sim.sh integration                           # run all 3 integration tests
#   scripts/run_sim.sh integration --program fibonacci       # run one integration test
#   scripts/run_sim.sh integration --program fibonacci --vcd # ...and dump a VCD waveform
#   scripts/run_sim.sh all                                   # unit + all integration tests
#
# Each demo program (fibonacci, bubble_sort, factorial) has its own dedicated
# integration testbench under tb/integration/, since the expected MAX_CYCLES
# and result checks differ per program.

set -euo pipefail

PROJ=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJ"

RTL_DIRS="rtl/top rtl/if_stage rtl/id_stage rtl/control rtl/ex_stage rtl/mem_stage rtl/wb_stage rtl/hazard"
RTL_FILES=$(for d in $RTL_DIRS; do find "$d" -name "*.v" 2>/dev/null; done | tr '\n' ' ')

usage() {
    echo "Usage: $0 [unit|integration|all] [--vcd] [--program fibonacci|bubble_sort|factorial]"
    exit 1
}

MODE=${1:-integration}
shift || true

VCD=""
PROGRAM=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vcd)       VCD="-DDUMP_VCD" ;;
        --program)   PROGRAM="$2"; shift ;;
        -h|--help)   usage ;;
        *) echo "Unknown arg: $1"; usage ;;
    esac
    shift
done

run_unit() {
    local tb="$1"
    local name
    name=$(basename "$tb" .v)
    echo "=== Unit: $name ==="
    iverilog -o "/tmp/${name}.vvp" "$tb" $RTL_FILES 2>&1 || { echo "COMPILE FAIL"; return 1; }
    vvp "/tmp/${name}.vvp"
    echo ""
}

# Map a program name to its dedicated integration testbench file.
tb_for_program() {
    case "$1" in
        fibonacci)   echo "tb/integration/tb_riscv_top.v" ;;
        bubble_sort) echo "tb/integration/tb_riscv_bubble_sort.v" ;;
        factorial)   echo "tb/integration/tb_riscv_factorial.v" ;;
        *) echo ""; return 1 ;;
    esac
}

run_integration_one() {
    local program="$1"
    local tb
    tb=$(tb_for_program "$program") || { echo "Unknown program: $program"; usage; }
    local name
    name=$(basename "$tb" .v)

    echo "=== Integration: $program ==="
    iverilog -o "/tmp/${name}.vvp" $VCD "$tb" $RTL_FILES 2>&1 \
        || { echo "COMPILE FAIL"; exit 1; }
    vvp "/tmp/${name}.vvp"

    if [[ -n "$VCD" ]]; then
        echo "VCD written — open with: gtkwave dump*.vcd"
    fi
    echo ""
}

run_all_integration() {
    for p in fibonacci bubble_sort factorial; do
        run_integration_one "$p"
    done
}

case "$MODE" in
    unit)
        for tb in tb/unit/tb_*.v; do
            run_unit "$tb" || true
        done
        ;;
    integration)
        if [[ -n "$PROGRAM" ]]; then
            run_integration_one "$PROGRAM"
        else
            run_all_integration
        fi
        ;;
    all)
        for tb in tb/unit/tb_*.v; do
            run_unit "$tb" || true
        done
        if [[ -n "$PROGRAM" ]]; then
            run_integration_one "$PROGRAM"
        else
            run_all_integration
        fi
        ;;
    *)
        usage
        ;;
esac

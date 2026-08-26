# RISC-V — RV32I 5-Stage Pipelined Processor

A classic 5-stage in-order RV32I pipeline (**IF → ID → EX → MEM → WB**) implemented in
synthesizable Verilog, with full data/control hazard resolution, a self-written
RV32I assembler, and a self-checking Icarus Verilog testbench suite (unit + integration).

```
        ┌────┐  IF/ID  ┌────┐  ID/EX  ┌────┐  EX/MEM   ┌─────┐  MEM/WB   ┌────┐
 PC ──► │ IF │ ──────► │ ID │ ──────► │ EX │ ────────► │ MEM │ ────────► │ WB │
        └────┘         └────┘         └────┘           └─────┘           └────┘
           ▲                                                                │
           │              Hazard Detection + Forwarding Unit                │
           └────────────────────────────────────────────────────────────────┘
```

## Features

- **ISA:** RV32I base integer instruction set (no M/F/privileged extensions)
- **Full hazard resolution:**
  - EX→EX and MEM→EX operand forwarding
  - Load-use hazard detection with 1-cycle stall + bubble insertion
  - Branch/jump resolution in EX with a static not-taken predictor and 2-cycle flush penalty
- **Harvard memory model** — separate instruction ROM and data RAM, so IF and MEM never
  contend for a bus
- **32×32-bit register file** — two async read ports, one sync write port, `x0` hardwired to 0
- **Self-written RV32I assembler** (`scripts/assemble.py`) — assembles `.s` → `.hex`
- **10 self-checking testbenches** — 8 unit tests (per-module) + 3 integration tests
  (Fibonacci, bubble sort, factorial) run on the full pipeline

## Repository Structure

```
.
├── rtl/                    # Synthesizable Verilog source
│   ├── top/                #   riscv_top.v — top-level pipeline instantiation
│   ├── if_stage/           #   PC register, instruction memory, IF/ID register
│   ├── id_stage/           #   instruction decoder, register file, immediate gen, ID/EX register
│   ├── control/             #   main decoder, ALU decoder, control unit
│   ├── ex_stage/           #   ALU, branch unit, EX/MEM register
│   ├── mem_stage/          #   data memory, load extender, MEM/WB register
│   ├── wb_stage/           #   writeback mux
│   └── hazard/             #   forwarding unit, hazard detection unit
├── tb/
│   ├── unit/                # Per-module self-checking testbenches
│   └── integration/         # Full-pipeline testbenches (one per demo program)
├── programs/
│   ├── asm/                 # RV32I assembly source (.s)
│   └── hex/                 # Assembled machine code (.hex), loaded by instr_mem.v
├── scripts/
│   ├── assemble.py          # RV32I assembler (.s -> .hex)
│   └── run_sim.sh           # Build/run script (Icarus Verilog)
└── docs/
    ├── microarchitecture.md # Per-stage microarchitecture description
    ├── hazard_analysis.md   # Data/control/structural hazard analysis
    └── interface_spec.md    # Inter-module port/signal specification
```

## Requirements

- [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog`, `vvp`) — v11+ recommended
- Python 3 (for the assembler, standard library only — no dependencies)
- [GTKWave](http://gtkwave.sourceforge.net/) (optional, for waveform viewing)

On Debian/Ubuntu:
```bash
sudo apt install iverilog gtkwave python3
```

## Running the Tests

All simulation is driven through `scripts/run_sim.sh`:

```bash
# Run all 8 unit tests
scripts/run_sim.sh unit

# Run all 3 integration tests (fibonacci, bubble_sort, factorial)
scripts/run_sim.sh integration

# Run one integration test
scripts/run_sim.sh integration --program fibonacci

# Run one integration test and dump a VCD waveform
scripts/run_sim.sh integration --program fibonacci --vcd
gtkwave dump.vcd

# Run everything (unit + integration)
scripts/run_sim.sh all
```

Expected output ends with `ALL PASS — 0 error(s)` for each unit test and `ALL PASS`
for each integration test.

### Re-assembling the demo programs

The `.hex` files in `programs/hex/` are already assembled and checked in, but if you
edit a `.s` source you can regenerate its `.hex`:

```bash
python3 scripts/assemble.py programs/asm/fibonacci.s -o programs/hex/fibonacci.hex
```

## Demo Programs

| Program        | Source                            | What it verifies                                  |
|-----------------|------------------------------------|----------------------------------------------------|
| `fibonacci`     | `programs/asm/fibonacci.s`         | Loops, branches, ALU add, memory store             |
| `bubble_sort`   | `programs/asm/bubble_sort.s`       | Nested loops, memory load/store, branch-heavy code |
| `factorial`     | `programs/asm/factorial.s`         | Multiplication-by-repeated-add, register reuse     |
| `comprehensive_test` | `programs/asm/comprehensive_test.s` | Broad instruction coverage (not wired to a testbench — for manual/waveform inspection) |

## Hazard Handling Summary

See [`docs/hazard_analysis.md`](docs/hazard_analysis.md) for the full writeup. In short:

- **RAW data hazards** are resolved by EX/MEM → EX and MEM/WB → EX forwarding.
- **Load-use hazards** (forwarding can't help — data isn't ready until MEM) are resolved
  by a 1-cycle stall + bubble, detected by `hazard_detect.v`.
- **Control hazards** (branches/jumps) are resolved in the EX stage with a static
  not-taken prediction and a 2-cycle flush on misprediction.
- **Structural hazards** are designed out entirely via the Harvard memory split and a
  2-read/1-write register file.

## Documentation

- [`docs/microarchitecture.md`](docs/microarchitecture.md) — stage-by-stage design description
- [`docs/hazard_analysis.md`](docs/hazard_analysis.md) — hazard detection and resolution mechanisms
- [`docs/interface_spec.md`](docs/interface_spec.md) — signal-level module interface spec

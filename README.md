# 🖥️ RISC-V RV32I 5-Stage Pipelined Processor

A classic **5-stage in-order RV32I RISC-V processor** implemented in **synthesizable Verilog**, following the **IF → ID → EX → MEM → WB** pipeline architecture.

The processor includes complete **data and control hazard resolution**, including operand forwarding, load-use hazard detection, pipeline stalls, and branch/jump flushing. The project also includes a **self-written RV32I assembler** for converting assembly programs into machine-code `.hex` files and a **self-checking Icarus Verilog testbench suite** covering both individual modules and full-pipeline programs.

<p align="center">

<img src="https://img.shields.io/badge/ISA-RV32I-blue" alt="RV32I">
<img src="https://img.shields.io/badge/HDL-Verilog-orange" alt="Verilog">
<img src="https://img.shields.io/badge/Pipeline-5--Stage-green" alt="5 Stage Pipeline">
<img src="https://img.shields.io/badge/Simulation-Icarus%20Verilog-purple" alt="Icarus Verilog">
<img src="https://img.shields.io/badge/Assembler-Python-red" alt="Python Assembler">
<img src="https://img.shields.io/badge/Architecture-Harvard-yellow" alt="Harvard Architecture">

</p>

---

## Why

A pipelined processor improves instruction throughput by allowing multiple instructions to occupy different stages of execution simultaneously.

However, pipelining introduces **data, control, and structural hazards** that must be handled correctly to maintain program execution.

This project implements a complete RV32I pipeline while specifically addressing:

- **RAW data hazards** through operand forwarding
- **Load-use hazards** through a 1-cycle pipeline stall
- **Control hazards** through branch/jump resolution and pipeline flushing
- **Structural hazards** through a Harvard memory architecture
- Correct register-file behavior with a hardwired `x0`
- Automated assembly and simulation of RV32I programs

## Features

- 🧠 **RV32I base integer instruction set**
- 🏗️ Classic **5-stage pipeline: IF → ID → EX → MEM → WB**
- 🔀 EX→EX operand forwarding
- 🔀 MEM→EX operand forwarding
- ⏸️ Load-use hazard detection
- ⏱️ 1-cycle stall and bubble insertion for load-use hazards
- 🚦 Branch and jump resolution in EX
- 🧹 2-cycle pipeline flush on control misprediction
- 🎯 Static **not-taken branch prediction**
- 💾 Harvard architecture with separate instruction and data memories
- 🧮 32 × 32-bit register file
- 📖 Two asynchronous read ports
- ✍️ One synchronous write port
- 🔒 `x0` hardwired to zero
- 🐍 Self-written RV32I assembler
- 🧪 Self-checking Verilog testbenches
- 📦 Unit and full-pipeline integration testing
- 📈 Optional VCD waveform generation
- 🖥️ GTKWave waveform inspection

## System Architecture

```text
                 ┌────┐   IF/ID   ┌────┐   ID/EX   ┌────┐
        PC ────► │ IF │ ────────► │ ID │ ────────► │ EX │
                 └────┘            └────┘            └────┘
                    ▲                  │                │
                    │                  │                │
                    │                  ▼                ▼
                    │            Register File      ALU / Branch
                    │                                   │
                    │                                   ▼
                    │                              ┌────────┐
                    │                    EX/MEM ──► │  MEM   │
                    │                              └────────┘
                    │                                   │
                    │                                   ▼
                    │                              ┌────────┐
                    │                    MEM/WB ──► │   WB   │
                    │                              └────────┘
                    │                                   │
                    └───────────────────────────────────┘
                              Hazard Control
````

**Flow:** instruction fetch → decode/register read → execute/branch → memory access → writeback.

A dedicated **hazard detection and forwarding unit** continuously monitors pipeline dependencies and controls forwarding, stalls, and flushes.

## Pipeline Stages

| Stage                       | Function                                                           |
| --------------------------- | ------------------------------------------------------------------ |
| **IF – Instruction Fetch**  | Fetches the next instruction using the program counter             |
| **ID – Instruction Decode** | Decodes the instruction, reads registers, and generates immediates |
| **EX – Execute**            | Performs ALU operations, comparisons, branches, and jumps          |
| **MEM – Memory Access**     | Performs load/store operations using data memory                   |
| **WB – Writeback**          | Writes ALU or memory results back to the register file             |

Pipeline registers separate the stages:

```text
IF → IF/ID → ID → ID/EX → EX → EX/MEM → MEM → MEM/WB → WB
```

## ISA

The processor implements the **RV32I base integer instruction set**.

It does not implement:

* M extension
* F extension
* Privileged extensions

The supported instruction set is intended for demonstrating the core RV32I integer datapath and pipeline behavior.

## Hazard Handling

Pipeline hazards are handled using dedicated forwarding and hazard-detection logic.

### Data Hazards

RAW (**Read After Write**) hazards are resolved using forwarding paths:

```text
EX/MEM ───────► EX
     │
     │ Forward
     ▼

MEM/WB ───────► EX
```

This allows dependent instructions to use recently produced results without unnecessarily stalling the pipeline.

### Load-Use Hazards

A load instruction cannot forward its result early enough when the immediately following instruction needs that value.

Therefore, the processor inserts a **1-cycle stall and bubble**.

```text
Load
 │
 ▼
MEM
 │
 ▼
Data Available
 │
 ▼
Dependent Instruction
```

The hazard detection unit identifies this condition and prevents incorrect execution.

### Control Hazards

Branches and jumps are resolved in the **EX stage**.

The processor uses a static **not-taken prediction**.

When the prediction is incorrect:

```text
Branch / Jump
      │
      ▼
Resolve in EX
      │
      ▼
Misprediction
      │
      ▼
Flush Pipeline
      │
      ▼
Correct PC
```

A **2-cycle flush penalty** is applied when a control-flow instruction changes the predicted execution path.

### Structural Hazards

Structural hazards are eliminated through a **Harvard memory architecture**.

```text
              ┌──────────────────┐
              │ Instruction ROM  │
              └────────┬─────────┘
                       │
                       ▼
                      IF

              ┌──────────────────┐
              │    Data RAM      │
              └────────┬─────────┘
                       │
                       ▼
                     MEM
```

Instruction and data memories are separated, so instruction fetch and data-memory access never compete for the same memory bus.

## Register File

The processor contains a **32 × 32-bit register file**.

### Features

* 32 general-purpose registers
* 32-bit register width
* Two asynchronous read ports
* One synchronous write port
* `x0` permanently hardwired to `0`

```text
       rs1 ─────►┌──────────────┐
                 │              │────► Read Data 1
       rs2 ─────►│ Register File│
                 │   32 × 32    │────► Read Data 2
                 │              │
       rd  ─────►│              │
                 └──────────────┘
                      ▲
                      │
                  Write Data
```

## Memory Architecture

The processor uses separate instruction and data memories.

### Instruction Memory

* Stores program instructions
* Accessed during the IF stage
* Implemented as instruction ROM

### Data Memory

* Used for load and store instructions
* Accessed during the MEM stage
* Implemented as data RAM

This separation eliminates structural conflicts between instruction fetch and memory operations.

## Technologies Used

* **Verilog** — synthesizable processor RTL
* **Icarus Verilog** — simulation and testbench execution
* **Python 3** — custom RV32I assembler
* **GTKWave** — optional waveform visualization
* **RV32I ISA** — processor instruction set architecture
* **Harvard Architecture** — separate instruction/data memory

## Assembler

The project includes a **self-written RV32I assembler** implemented in Python.

```text
RV32I Assembly (.s)
        │
        ▼
 scripts/assemble.py
        │
        ▼
Machine Code (.hex)
        │
        ▼
Instruction Memory
        │
        ▼
RISC-V Pipeline
```

The assembler converts `.s` assembly source files into `.hex` machine-code files that can be loaded into the processor's instruction memory.

The assembler uses only the **Python standard library** and does not require external dependencies.

## Repository Structure

```text
.
├── rtl/
│   ├── top/
│   │   └── riscv_top.v
│   │
│   ├── if_stage/
│   │   ├── PC register
│   │   ├── instruction memory
│   │   └── IF/ID register
│   │
│   ├── id_stage/
│   │   ├── instruction decoder
│   │   ├── register file
│   │   ├── immediate generator
│   │   └── ID/EX register
│   │
│   ├── control/
│   │   ├── main decoder
│   │   ├── ALU decoder
│   │   └── control unit
│   │
│   ├── ex_stage/
│   │   ├── ALU
│   │   ├── branch unit
│   │   └── EX/MEM register
│   │
│   ├── mem_stage/
│   │   ├── data memory
│   │   ├── load extender
│   │   └── MEM/WB register
│   │
│   ├── wb_stage/
│   │   └── writeback mux
│   │
│   └── hazard/
│       ├── forwarding unit
│       └── hazard detection unit
│
├── tb/
│   ├── unit/
│   │   └── per-module self-checking testbenches
│   │
│   └── integration/
│       └── full-pipeline testbenches
│
├── programs/
│   ├── asm/
│   │   └── RV32I assembly source
│   │
│   └── hex/
│       └── assembled machine code
│
├── scripts/
│   ├── assemble.py
│   └── run_sim.sh
│
└── docs/
    ├── microarchitecture.md
    ├── hazard_analysis.md
    └── interface_spec.md
```

## Getting Started

### Requirements

* **Icarus Verilog** (`iverilog`, `vvp`) — v11+ recommended
* **Python 3**
* **GTKWave** — optional for waveform viewing

On Debian/Ubuntu:

```bash
sudo apt install iverilog gtkwave python3
```

### 1. Clone the Repository

```bash
git clone https://github.com/k1thhh/<repository-name>.git
cd <repository-name>
```

### 2. Run Unit Tests

Run all module-level self-checking testbenches:

```bash
scripts/run_sim.sh unit
```

Expected output ends with:

```text
ALL PASS — 0 error(s)
```

### 3. Run Integration Tests

Run all full-pipeline programs:

```bash
scripts/run_sim.sh integration
```

### 4. Run a Specific Program

For example, to run the Fibonacci integration test:

```bash
scripts/run_sim.sh integration --program fibonacci
```

### 5. Generate Waveforms

To generate a VCD waveform:

```bash
scripts/run_sim.sh integration --program fibonacci --vcd
```

Then open it using GTKWave:

```bash
gtkwave dump.vcd
```

### 6. Run Everything

Run both unit and integration tests:

```bash
scripts/run_sim.sh all
```

## Demo Programs

| Program              | Source                              | What It Verifies                                    |
| -------------------- | ----------------------------------- | --------------------------------------------------- |
| `fibonacci`          | `programs/asm/fibonacci.s`          | Loops, branches, ALU addition, memory store         |
| `bubble_sort`        | `programs/asm/bubble_sort.s`        | Nested loops, memory load/store, branch-heavy code  |
| `factorial`          | `programs/asm/factorial.s`          | Multiplication by repeated addition, register reuse |
| `comprehensive_test` | `programs/asm/comprehensive_test.s` | Broad RV32I instruction coverage                    |

The first three programs have dedicated integration testbenches, while `comprehensive_test` is intended for manual or waveform-based inspection.

## Re-Assembling Programs

The `.hex` files are already assembled and included in the repository.

If an assembly source file is modified, it can be reassembled using:

```bash
python3 scripts/assemble.py programs/asm/fibonacci.s -o programs/hex/fibonacci.hex
```

The generated `.hex` file can then be loaded by the instruction memory.

## Testing

The project contains both **unit-level and integration-level verification**.

### Unit Tests

Individual processor modules are tested independently, including the datapath and control components.

### Integration Tests

The complete 5-stage pipeline is tested using:

* Fibonacci
* Bubble Sort
* Factorial

The testbenches are **self-checking**, meaning they automatically detect incorrect outputs rather than relying only on waveform inspection.

## Expected Results

Successful execution of the test suite should produce:

```text
ALL PASS — 0 error(s)
```

for unit tests and:

```text
ALL PASS
```

for each successful integration test.

## Documentation

Detailed design documentation is provided in the `docs/` directory:

* [`docs/microarchitecture.md`](docs/microarchitecture.md) — stage-by-stage processor microarchitecture
* [`docs/hazard_analysis.md`](docs/hazard_analysis.md) — data, control, and structural hazard handling
* [`docs/interface_spec.md`](docs/interface_spec.md) — inter-module port and signal specification

## Performance & Design Characteristics

The processor demonstrates:

* 5-stage instruction pipelining
* In-order instruction execution
* Forwarding-based RAW hazard resolution
* 1-cycle load-use stalls
* 2-cycle control-hazard flushes
* Static not-taken branch prediction
* Separate instruction and data memories
* Parallel register-file reads
* Synthesizable Verilog RTL

## Limitations

* Only the **RV32I base integer ISA** is implemented.
* M extension instructions such as hardware multiplication/division are not included.
* Floating-point instructions are not supported.
* Privileged instructions and operating-system support are not implemented.
* Branch prediction is limited to a static not-taken strategy.
* The project focuses on simulation and RTL verification rather than FPGA/ASIC implementation.

## Future Scope

* Implement the RV32M multiplication/division extension
* Add CSR and privileged instruction support
* Implement more advanced branch prediction
* Add branch target buffers
* Introduce cache memories
* Add instruction and data caches
* Implement deeper or configurable pipelines
* Add FPGA synthesis and hardware testing
* Perform timing and area analysis after synthesis
* Add formal verification
* Expand the assembler to support additional RISC-V extensions
* Implement interrupt and exception handling
* Explore superscalar or out-of-order execution

## Project Highlights

* 🔹 **Classic 5-stage RV32I pipeline**
* 🔹 Fully synthesizable Verilog RTL
* 🔹 **IF → ID → EX → MEM → WB**
* 🔹 EX→EX forwarding
* 🔹 MEM→EX forwarding
* 🔹 Load-use hazard detection
* 🔹 1-cycle stall and bubble insertion
* 🔹 Branch/jump resolution in EX
* 🔹 2-cycle control-hazard flush
* 🔹 Static not-taken branch prediction
* 🔹 Harvard instruction/data memory architecture
* 🔹 32 × 32-bit register file
* 🔹 Hardwired `x0`
* 🔹 Custom Python RV32I assembler
* 🔹 Self-checking unit testbenches
* 🔹 Full-pipeline integration testing
* 🔹 Fibonacci, bubble-sort, and factorial programs
* 🔹 Optional GTKWave waveform analysis

## Key Concepts Demonstrated

* RISC-V ISA
* RV32I Architecture
* Processor Microarchitecture
* 5-Stage Pipelining
* Instruction Fetch
* Instruction Decode
* ALU Execution
* Memory Access
* Writeback
* Data Hazards
* Control Hazards
* Structural Hazards
* Operand Forwarding
* Pipeline Stalling
* Pipeline Flushing
* Branch Prediction
* Register Files
* Harvard Architecture
* Synthesizable Verilog
* Digital Processor Design
* RTL Verification
* Computer Architecture

## Authors

**Kirthana S**

## Acknowledgements

* **RISC-V Foundation** — RV32I instruction set architecture
* **Icarus Verilog** — open-source Verilog simulation
* **GTKWave** — waveform visualization

```
```

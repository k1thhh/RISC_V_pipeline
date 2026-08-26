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

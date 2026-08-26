# RV32I Microarchitecture Specification

This document details the microarchitecture of the 5-stage pipelined RV32I processor. The processor implements the classic RISC pipeline: **Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory Access (MEM), and Write-Back (WB)**.

## 1. Instruction Fetch (IF) Stage

The IF stage is responsible for fetching instructions from the instruction memory and determining the next Program Counter (PC).

**Key Components:**
* **Program Counter (PC) Register:** Holds the current address. It updates on every positive clock edge unless stalled.
* **Instruction Memory (ROM):** A read-only memory block initialized with the compiled `.hex` program. It reads the instruction at the current PC asynchronously.
* **Next PC Multiplexer:** Selects between `PC + 4` (default), or the `branch_target` provided by the EX stage if a branch/jump is taken.

**Pipeline Register Output (`IF/ID`):**
* `ifid_pc`: The PC of the fetched instruction.
* `ifid_pc_plus4`: The address of the next sequential instruction.
* `ifid_instr`: The 32-bit fetched instruction word.

## 2. Instruction Decode (ID) Stage

The ID stage extracts fields from the instruction word, reads the register file, generates the immediate, and decodes the control signals.

**Key Components:**
* **Instruction Decoder:** Slices the 32-bit instruction into `opcode`, `funct3`, `funct7`, `rs1`, `rs2`, and `rd`.
* **Register File:** A 32-entry by 32-bit register file. It has two asynchronous read ports (`rs1`, `rs2`) and one synchronous write port (`rd`). Register `x0` is hardwired to 0. 
* **Immediate Generator:** Extracts and sign-extends the immediate value based on the instruction format (I, S, B, U, J).
* **Control Unit:** Uses the `opcode`, `funct3`, and `funct7` to generate datapath control signals (e.g., `RegWrite`, `MemRead`, `ALUSrc`, `ALUControl`).

**Pipeline Register Output (`ID/EX`):**
* Passes the decoded control signals, extracted `rs1_data` and `rs2_data`, sign-extended `imm`, and register addresses (`rs1`, `rs2`, `rd`) to the EX stage.

## 3. Execute (EX) Stage

The EX stage performs all arithmetic/logic operations and evaluates branch conditions.

**Key Components:**
* **Arithmetic Logic Unit (ALU):** A purely combinational 32-bit ALU that performs ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, and SLTU. 
* **Branch Unit:** Compares `rs1_data` and `rs2_data` to evaluate branch conditions (e.g., `BEQ`, `BLT`). It also calculates the branch target address (`PC + imm` for Branches and JAL, `rs1 + imm` for JALR).
* **Operand Multiplexers:** Select between register data, forwarded data, and immediate values before feeding into the ALU.

**Pipeline Register Output (`EX/MEM`):**
* Passes the `alu_result`, the data to be written to memory (`rs2_data`), and memory/writeback control signals to the MEM stage.

## 4. Memory Access (MEM) Stage

The MEM stage interacts with the data memory for load and store instructions.

**Key Components:**
* **Data Memory (RAM):** A byte-addressable synchronous RAM. It uses the `alu_result` as the memory address. 
* **Load Extension Unit:** Formats the raw 32-bit data read from memory based on the instruction type. It handles sign-extension for byte/halfword loads (`LB`, `LH`) and zero-extension for unsigned loads (`LBU`, `LHU`).

**Pipeline Register Output (`MEM/WB`):**
* Passes the `alu_result`, the formatted `mem_data`, and the WB control signals (`RegWrite`, `MemToReg`) to the final stage.

## 5. Write-Back (WB) Stage

The WB stage routes the final computed result back to the Register File.

**Key Components:**
* **Write-Back Multiplexer:** Selects the data to write back to the destination register (`rd`). The choices are:
  1. `alu_result` (for arithmetic instructions)
  2. `mem_data` (for load instructions)
  3. `PC + 4` (for JAL and JALR instructions, storing the return address)

This stage does not have a pipeline register output, as the data directly drives the write port of the Register File in the ID stage.

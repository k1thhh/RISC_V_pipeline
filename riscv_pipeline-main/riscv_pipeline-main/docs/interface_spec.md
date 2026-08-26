# RV32I 5-Stage Pipelined Processor — Top-Level Architecture Specification

---

## 1. Scope and Purpose

This document is the single source of truth for all inter-module interfaces in the RV32I 5-stage pipelined processor. Every contributor must implement their module's ports to match the signal names, widths, and semantics defined here. No signal names or widths should be invented locally — raise a spec change request (edit this document) if a new signal is needed.

---

## 2. Architecture Overview

A classic 5-stage in-order pipeline: **IF → ID → EX → MEM → WB**

```
        ┌────┐  IF/ID  ┌────┐  ID/EX  ┌────┐  EX/MEM   ┌─────┐  MEM/WB   ┌────┐
 PC ──► │ IF │ ──────► │ ID │ ──────► │ EX │ ────────► │ MEM │ ────────► │ WB │
        └────┘         └────┘         └────┘           └─────┘           └────┘
           ▲                                                                │
           │              Hazard Detection + Forwarding Unit                │
           └────────────────────────────────────────────────────────────────┘
```

- **ISA:** RV32I base integer (no M, F, or privileged extensions)
- **Data width:** 32 bits throughout
- **Address width:** 32 bits (byte-addressed)
- **Register file:** 32 × 32-bit general-purpose registers (x0 hardwired to 0)
- **Memory model:** Harvard (separate instruction and data memories for simplicity)
- **Reset:** Synchronous active-high `rst`

---

## 3. Global Signals

These are connected to every module.

| Signal | Width | Direction (from top) | Description |
|--------|-------|----------------------|-------------|
| `clk`  | 1     | Input                | System clock, rising-edge triggered |
| `rst`  | 1     | Input                | Synchronous reset, active-high |

---

## 4. Top-Level Module Port List

```verilog
module rv32i_top (
    input  wire        clk,
    input  wire        rst,
    // Debug / testbench observation ports
    output wire [31:0] tb_pc,           // Current PC (IF stage)
    output wire [31:0] tb_alu_result,   // ALU result (EX stage)
    output wire [31:0] tb_reg_wb_data,  // Data written back to register file
    output wire [4:0]  tb_reg_wb_addr,  // Destination register address at WB
    output wire        tb_reg_wb_en     // Register write enable at WB
);
```

Internal wires are declared in `rv32i_top.v` and not exposed in sub-module ports beyond what is listed in each section below.

---

## 5. Pipeline Register Definitions

Pipeline registers are the contracts between stages. Each register's fields are listed; any module feeding a stage writes these fields and any module reading from a stage reads exactly these fields.

### 5.1 IF/ID Register

Latched at the end of the IF stage.

| Field | Width | Description |
|-------|-------|-------------|
| `ifid_pc` | 32 | PC of the fetched instruction |
| `ifid_pc_plus4` | 32 | PC + 4 (next sequential address) |
| `ifid_instr` | 32 | Raw instruction word |

### 5.2 ID/EX Register

Latched at the end of the ID stage.

| Field | Width | Description |
|-------|-------|-------------|
| `idex_pc` | 32 | Forwarded PC |
| `idex_pc_plus4` | 32 | Forwarded PC+4 |
| `idex_rs1_data` | 32 | Register file read data 1 |
| `idex_rs2_data` | 32 | Register file read data 2 |
| `idex_imm` | 32 | Sign-extended immediate |
| `idex_rs1_addr` | 5  | Source register 1 address (for forwarding) |
| `idex_rs2_addr` | 5  | Source register 2 address (for forwarding) |
| `idex_rd_addr`  | 5  | Destination register address |
| `idex_alu_op`   | 4  | ALU operation code (see Section 7.1) |
| `idex_alu_src`  | 1  | ALU operand B select: 0 = rs2_data, 1 = imm |
| `idex_reg_write`| 1  | Register file write enable |
| `idex_mem_read` | 1  | Data memory read enable |
| `idex_mem_write`| 1  | Data memory write enable |
| `idex_mem_to_reg`| 2 | WB mux select (see Section 7.2) |
| `idex_branch`   | 1  | Instruction is a branch |
| `idex_jump`     | 1  | Instruction is JAL/JALR |
| `idex_funct3`   | 3  | funct3 field (passed for branch type / mem width) |

### 5.3 EX/MEM Register

Latched at the end of the EX stage.

| Field | Width | Description |
|-------|-------|-------------|
| `exmem_pc_plus4` | 32 | PC+4 (for JAL/JALR link address) |
| `exmem_alu_result` | 32 | ALU output / branch target / memory address |
| `exmem_rs2_data` | 32 | Store data (after forwarding) |
| `exmem_rd_addr` | 5  | Destination register address |
| `exmem_zero`    | 1  | ALU zero flag |
| `exmem_reg_write`| 1 | Register file write enable |
| `exmem_mem_read` | 1 | Data memory read enable |
| `exmem_mem_write`| 1 | Data memory write enable |
| `exmem_mem_to_reg`| 2 | WB mux select |
| `exmem_branch`  | 1  | Branch instruction flag |
| `exmem_jump`    | 1  | Jump instruction flag |
| `exmem_funct3`  | 3  | funct3 (for branch condition / mem width) |

### 5.4 MEM/WB Register

Latched at the end of the MEM stage.

| Field | Width | Description |
|-------|-------|-------------|
| `memwb_alu_result` | 32 | ALU result (for non-memory instructions) |
| `memwb_mem_data`   | 32 | Data read from memory |
| `memwb_pc_plus4`   | 32 | PC+4 (for JAL/JALR link) |
| `memwb_rd_addr`    | 5  | Destination register address |
| `memwb_reg_write`  | 1  | Register file write enable |
| `memwb_mem_to_reg` | 2  | WB mux select |

---

## 6. Sub-Module Port Specifications

### 6.1 IF Stage — `if_stage.v` 

```verilog
module if_stage (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,           // From Hazard Unit: freeze PC and IF/ID
    input  wire        flush,           // From Hazard Unit: insert NOP into IF/ID
    input  wire        branch_taken,    // From EX stage: branch/jump resolved
    input  wire [31:0] branch_target,   // From EX stage: target PC
    output wire [31:0] ifid_pc,
    output wire [31:0] ifid_pc_plus4,
    output wire [31:0] ifid_instr
);
```

**Notes:**
- Instruction memory is internal to this module (ROM, initialized from a `.hex` file)
- On `flush`: output a NOP (`32'h00000013`, i.e., `addi x0, x0, 0`) into the IF/ID register
- On `stall`: hold current IF/ID values, do not advance PC

---

### 6.2 Instruction Decoder + Immediate Generator — `id_stage.v` 

```verilog
module id_stage (
    input  wire        clk,
    input  wire        rst,
    // From IF/ID register
    input  wire [31:0] ifid_pc,
    input  wire [31:0] ifid_pc_plus4,
    input  wire [31:0] ifid_instr,
    // From Register File (Abhimanyu's module)
    input  wire [31:0] rf_rdata1,
    input  wire [31:0] rf_rdata2,
    // Outputs to Register File
    output wire [4:0]  rf_rs1_addr,
    output wire [4:0]  rf_rs2_addr,
    // Outputs to ID/EX register (all idex_ fields from Section 5.2)
    output wire [31:0] idex_pc,
    output wire [31:0] idex_pc_plus4,
    output wire [31:0] idex_rs1_data,
    output wire [31:0] idex_rs2_data,
    output wire [31:0] idex_imm,
    output wire [4:0]  idex_rs1_addr,
    output wire [4:0]  idex_rs2_addr,
    output wire [4:0]  idex_rd_addr,
    output wire [3:0]  idex_alu_op,
    output wire        idex_alu_src,
    output wire        idex_reg_write,
    output wire        idex_mem_read,
    output wire        idex_mem_write,
    output wire [1:0]  idex_mem_to_reg,
    output wire        idex_branch,
    output wire        idex_jump,
    output wire [2:0]  idex_funct3
);
```

**Notes:**
- `id_stage` handles field extraction (`opcode`, `funct3`, `funct7`, `rs1`, `rs2`, `rd`)
- Immediate generation covers all six RV32I immediate encodings: I, S, B, U, J, and R (zero immediate)
- Control signals are generated here by Vivaan calling into the Control Unit (Anirudh's module) — see Section 6.5 for the interface

---

### 6.3 Register File — `reg_file.v` 

```verilog
module reg_file (
    input  wire        clk,
    input  wire        rst,
    // Read ports (combinational)
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    // Write port (synchronous, rising edge)
    input  wire [4:0]  rd_addr,
    input  wire [31:0] wdata,
    input  wire        reg_write
);
```

**Notes:**
- x0 is hardwired to 0; writes to x0 are silently ignored
- Read is **combinational** (same-cycle read)
- **Write-then-read forwarding:** if `rd_addr == rs1_addr` and `reg_write` is high, `rdata1` returns `wdata` (avoids WB→ID hazard without a stall). Confirm with Anirudh if this is implemented here or in the Hazard Unit.

---

### 6.4 ALU — `alu.v` 

```verilog
module alu (
    input  wire [31:0] operand_a,       // rs1 data or forwarded value
    input  wire [31:0] operand_b,       // rs2 data, immediate, or forwarded value
    input  wire [3:0]  alu_op,          // Operation select (see Section 7.1)
    output wire [31:0] result,
    output wire        zero              // result == 32'h0
);
```

**Purely combinational — no clock input.**

---

### 6.5 Control Unit — `control_unit.v` 

```verilog
module control_unit (
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    output wire [3:0]  alu_op,
    output wire        alu_src,
    output wire        reg_write,
    output wire        mem_read,
    output wire        mem_write,
    output wire [1:0]  mem_to_reg,
    output wire        branch,
    output wire        jump
);
```

**Purely combinational.**

---

### 6.6 Branch and Jump Unit — `branch_unit.v` 

```verilog
module branch_unit (
    input  wire [31:0] rs1_data,        // After forwarding
    input  wire [31:0] rs2_data,        // After forwarding
    input  wire [31:0] pc,              // ID/EX PC
    input  wire [31:0] pc_plus4,        // ID/EX PC+4
    input  wire [31:0] imm,             // Sign-extended immediate
    input  wire [2:0]  funct3,          // Branch type
    input  wire        branch,          // Is a branch instruction
    input  wire        jump,            // Is JAL/JALR
    output wire        branch_taken,    // To IF stage PC mux
    output wire [31:0] branch_target    // Target PC
);
```

**Purely combinational.** Branch resolution happens in the **EX stage** (single branch penalty = 1 cycle flush of IF/ID and ID/EX on taken branch).

---

### 6.7 EX/MEM and MEM Stage — `mem_stage.v` 

```verilog
module mem_stage (
    input  wire        clk,
    input  wire        rst,
    // From EX/MEM register
    input  wire [31:0] exmem_alu_result,
    input  wire [31:0] exmem_rs2_data,
    input  wire [4:0]  exmem_rd_addr,
    input  wire [31:0] exmem_pc_plus4,
    input  wire        exmem_mem_read,
    input  wire        exmem_mem_write,
    input  wire        exmem_reg_write,
    input  wire [1:0]  exmem_mem_to_reg,
    input  wire [2:0]  exmem_funct3,    // For byte/half/word access width
    // Outputs to MEM/WB register
    output wire [31:0] memwb_alu_result,
    output wire [31:0] memwb_mem_data,
    output wire [31:0] memwb_pc_plus4,
    output wire [4:0]  memwb_rd_addr,
    output wire        memwb_reg_write,
    output wire [1:0]  memwb_mem_to_reg
);
```

**Notes:**
- Data memory is internal to this module (RAM, word-addressed internally but byte-addressed at the interface)
- Supports `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`, `SW` via `funct3`

---

### 6.8 Hazard Detection + Forwarding Unit — `hazard_unit.v` (Owner: Dev)

```verilog
module hazard_unit (
    // Register addresses flowing through the pipeline
    input  wire [4:0]  idex_rs1_addr,
    input  wire [4:0]  idex_rs2_addr,
    input  wire [4:0]  idex_rd_addr,
    input  wire        idex_mem_read,
    input  wire [4:0]  exmem_rd_addr,
    input  wire        exmem_reg_write,
    input  wire [4:0]  memwb_rd_addr,
    input  wire        memwb_reg_write,
    // Stall / flush control
    output wire        stall,           // To IF stage and IF/ID register
    output wire        flush,           // To IF/ID and ID/EX registers (on branch)
    // Forwarding mux selects
    output wire [1:0]  fwd_a_sel,       // Operand A select (see Section 7.3)
    output wire [1:0]  fwd_b_sel        // Operand B select
);
```

---

### 6.9 Verification and Testbench — `tb_rv32i_top.v` 

No module ports — this is a simulation-only file. It should:
- Drive `clk` and `rst`
- Load instruction memory via a task or `$readmemh`
- Monitor the `tb_` debug ports on `rv32i_top`
- Run at minimum: a NOP sled, `addi`/`add`/`sub`, a load-use hazard sequence, a taken branch, and `JAL`

---

## 7. Encoding Tables

### 7.1 `alu_op` Encoding (4 bits)

| `alu_op` | Operation | Notes |
|----------|-----------|-------|
| `4'b0000` | ADD  | `add`, `addi`, loads, stores, `auipc` address |
| `4'b0001` | SUB  | `sub` |
| `4'b0010` | AND  | `and`, `andi` |
| `4'b0011` | OR   | `or`, `ori` |
| `4'b0100` | XOR  | `xor`, `xori` |
| `4'b0101` | SLL  | `sll`, `slli` |
| `4'b0110` | SRL  | `srl`, `srli` |
| `4'b0111` | SRA  | `sra`, `srai` |
| `4'b1000` | SLT  | `slt`, `slti` |
| `4'b1001` | SLTU | `sltu`, `sltiu` |
| `4'b1010` | LUI  | Pass operand B (upper immediate) |
| `4'b1111` | NOP  | Reserved / bubble |

### 7.2 `mem_to_reg` WB Mux Encoding (2 bits)

| `mem_to_reg` | WB data source |
|--------------|----------------|
| `2'b00` | ALU result |
| `2'b01` | Data memory read data |
| `2'b10` | PC + 4 (JAL/JALR link address) |
| `2'b11` | Reserved |

### 7.3 Forwarding Mux Select Encoding (2 bits each)

Applies to both `fwd_a_sel` and `fwd_b_sel`:

| Value | Source |
|-------|--------|
| `2'b00` | No forwarding — use ID/EX register file data |
| `2'b01` | Forward from EX/MEM (ALU result, one cycle old) |
| `2'b10` | Forward from MEM/WB (two cycles old) |
| `2'b11` | Reserved |

---

## 8. Hazard Handling Summary

| Hazard | Detection | Resolution |
|--------|-----------|------------|
| Load-use RAW | `idex_mem_read` && (`idex_rd == ifid_rs1` or `idex_rd == ifid_rs2`) | Stall 1 cycle (freeze PC + IF/ID, bubble into ID/EX) |
| EX-EX RAW | `exmem_reg_write` && `exmem_rd == idex_rs1/rs2` | Forward EX/MEM ALU result to EX operand |
| MEM-EX RAW | `memwb_reg_write` && `memwb_rd == idex_rs1/rs2` | Forward MEM/WB result to EX operand |
| Control (taken branch) | Branch resolved in EX | Flush IF/ID and ID/EX (2-cycle penalty) |
| Control (JAL) | Resolved in ID | Flush IF/ID (1-cycle penalty) |

---

## 9. File Structure

```
rv32i/
├── rtl/
│   ├── rv32i_top.v         
│   ├── if_stage.v           
│   ├── id_stage.v           
│   ├── control_unit.v       
│   ├── reg_file.v           
│   ├── alu.v                
│   ├── branch_unit.v        
│   ├── mem_stage.v          
│   └── hazard_unit.v        
├── tb/
│   └── tb_rv32i_top.v       
├── mem/
│   └── program.hex          # Test program
└── spec/
    └── rv32i_top_spec.md    # This document
```

---


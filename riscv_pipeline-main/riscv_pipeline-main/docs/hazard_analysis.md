# RV32I Hazard Analysis and Resolution

In a pipelined processor, instructions overlap in execution. This overlap can lead to hazards when an instruction depends on the result of a previous instruction that has not yet completed. The RV32I processor successfully resolves data and control hazards to maintain a CPI (Cycles Per Instruction) close to 1.0.

## 1. Data Hazards (RAW - Read After Write)

A data hazard occurs when an instruction in the ID stage needs to read a register (`rs1` or `rs2`) that is currently being written to by a preceding instruction further down the pipeline (in EX, MEM, or WB).

### Forwarding (Bypassing)
To avoid stalling the pipeline for every data hazard, the **Forwarding Unit** provides bypass paths. It monitors the destination register (`rd`) of instructions in the EX/MEM and MEM/WB registers. If they match the source registers (`rs1`, `rs2`) of the instruction currently in the EX stage, the unit intercepts the ALU inputs.

1. **EX-EX Forwarding (Priority 1):**
   * If the previous instruction (now in MEM) modifies the register needed by the current EX instruction, the ALU output from the EX/MEM register is directly routed back to the ALU inputs.
   * *Condition:* `exmem_reg_write == 1` and `exmem_rd != 0` and `exmem_rd == idex_rs1/rs2`

2. **MEM-EX Forwarding (Priority 2):**
   * If the instruction two cycles ago (now in WB) modifies the register needed by the current EX instruction, the write-back data from the MEM/WB register is routed to the ALU inputs.
   * *Condition:* `memwb_reg_write == 1` and `memwb_rd != 0` and `memwb_rd == idex_rs1/rs2` (and EX-EX forwarding is not active for this register).

### Load-Use Hazards
A special type of data hazard occurs when a Load instruction (`LW`, `LB`, etc.) is immediately followed by an instruction that needs the loaded data. Because memory data is only available at the end of the MEM stage, forwarding alone cannot resolve this in time for the ALU.

* **Resolution:** The **Hazard Detection Unit** inserts a **1-cycle stall**.
* **Mechanism:** 
  1. Detect: `idex_mem_read == 1` and (`idex_rd == ifid_rs1` or `idex_rd == ifid_rs2`).
  2. Stall IF and ID: The `PC` and the `IF/ID` pipeline registers are disabled (frozen) for 1 cycle.
  3. Insert Bubble: The control signals in the `ID/EX` register are flushed (forced to 0), effectively injecting a NOP into the EX stage.
  4. After 1 cycle, the loaded data reaches the MEM/WB register and can be successfully forwarded using MEM-EX forwarding.

## 2. Control Hazards

A control hazard occurs when the pipeline fetches instructions sequentially, but a branch or jump instruction alters the flow of control, making the sequentially fetched instructions invalid.

### Branch Resolution in EX Stage
The processor evaluates all branch conditions (`BEQ`, `BNE`, `BLT`, etc.) and jump targets in the **EX stage**. The branch predictor relies on a **static "not-taken" prediction**, meaning the processor always assumes branches will not be taken and continues fetching sequentially.

* **Taken Branch Penalty (2 cycles):**
  If a branch evaluates to "taken" in the EX stage, the two instructions fetched sequentially behind it (currently in the IF and ID stages) are wrong. 
  * **Resolution:** The Hazard Detection Unit flushes both the `IF/ID` and `ID/EX` pipeline registers (injecting NOPs) and routes the calculated `branch_target` to the PC.

### Jump Resolution (JAL/JALR)
Jumps are unconditional and always change the flow of control. Because JAL and JALR targets are also computed in the EX stage alongside branches, they incur the same flush penalties as a taken branch.

## 3. Structural Hazards

Structural hazards occur when two instructions require the same hardware resource simultaneously. 
* **Resolution:** The processor is carefully designed to avoid structural hazards entirely. It utilizes a Harvard memory architecture (separate Instruction ROM and Data RAM) so that IF and MEM stages never compete for a single memory bus. The Register File supports simultaneous 2-port reads and 1-port writes, with a defined write-before-read behavior to avoid collisions.

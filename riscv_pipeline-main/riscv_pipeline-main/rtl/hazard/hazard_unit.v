// =============================================================================
// hazard_unit.v — Combined Hazard Detection + Forwarding Unit
// Stage: Combinational logic sitting beside the ID/EX boundary
//
// Responsibilities:
//   1. Load-use hazard detection → stall (freeze PC + IF/ID, bubble into ID/EX)
//   2. EX-EX forwarding  (Priority 1): EX/MEM ALU result → EX ALU input
//   3. MEM-EX forwarding (Priority 2): MEM/WB writeback data → EX ALU input
//
// Note: Control hazard flush (branch/jump) is driven by branch_taken directly
//       from branch_unit in riscv_top.v and does NOT go through this module.
//       The flush port has been removed to avoid the misleading stub.
// =============================================================================

module hazard_unit (
    // ID stage source registers (instruction in ID — for load-use stall detection)
    input  wire [4:0]  ifid_rs1_addr,
    input  wire [4:0]  ifid_rs2_addr,
    // EX stage source and destination registers (for forwarding)
    input  wire [4:0]  idex_rs1_addr,
    input  wire [4:0]  idex_rs2_addr,
    input  wire [4:0]  idex_rd_addr,
    input  wire        idex_mem_read,
    // EX/MEM and MEM/WB register info (forwarding sources)
    input  wire [4:0]  exmem_rd_addr,
    input  wire        exmem_reg_write,
    input  wire [4:0]  memwb_rd_addr,
    input  wire        memwb_reg_write,

    output wire        stall,       // Freeze PC + IF/ID; inject NOP bubble into ID/EX
    output wire [1:0]  fwd_a_sel,  // Forwarding mux select for ALU operand A
    output wire [1:0]  fwd_b_sel   // Forwarding mux select for ALU operand B
);

    // -------------------------------------------------------------------------
    // Load-use hazard: load is in EX (idex_mem_read=1), consumer is in ID.
    // Compare load's rd against the ID instruction's source registers.
    // -------------------------------------------------------------------------
    wire load_use = idex_mem_read &&
                    ((idex_rd_addr == ifid_rs1_addr) || (idex_rd_addr == ifid_rs2_addr)) &&
                    (idex_rd_addr != 5'h0);

    assign stall = load_use;

    // -------------------------------------------------------------------------
    // EX-EX forwarding (Priority 1 — most recent writer wins)
    // MEM-EX forwarding (Priority 2)
    // fwd_sel encoding: 2'b00 = no forward (use reg file),
    //                   2'b01 = forward from EX/MEM ALU result,
    //                   2'b10 = forward from MEM/WB writeback data
    // -------------------------------------------------------------------------
    assign fwd_a_sel = (exmem_reg_write && exmem_rd_addr != 5'h0 && exmem_rd_addr == idex_rs1_addr) ? 2'b01 :
                       (memwb_reg_write && memwb_rd_addr != 5'h0 && memwb_rd_addr == idex_rs1_addr) ? 2'b10 :
                                                                                                       2'b00;

    assign fwd_b_sel = (exmem_reg_write && exmem_rd_addr != 5'h0 && exmem_rd_addr == idex_rs2_addr) ? 2'b01 :
                       (memwb_reg_write && memwb_rd_addr != 5'h0 && memwb_rd_addr == idex_rs2_addr) ? 2'b10 :
                                                                                                       2'b00;

endmodule

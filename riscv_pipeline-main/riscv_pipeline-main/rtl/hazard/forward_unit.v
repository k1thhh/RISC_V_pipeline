// =============================================================================
// forward_unit.v — Standalone Forwarding Unit
//
// NOTE: riscv_top.v uses hazard_unit.v (the combined hazard+forward module).
//       This standalone module is kept for unit testing purposes only.
//
// Forwarding mux encoding:
//   2'b00 = no forward  (use ID/EX register file data)
//   2'b01 = EX-EX forward (use EX/MEM ALU result)
//   2'b10 = MEM-EX forward (use MEM/WB writeback data)
// =============================================================================

module forward_unit (
    // EX stage source registers
    input  wire [4:0]  idex_rs1_addr,
    input  wire [4:0]  idex_rs2_addr,
    // EX/MEM and MEM/WB register info
    input  wire [4:0]  exmem_rd_addr,
    input  wire        exmem_reg_write,
    input  wire [4:0]  memwb_rd_addr,
    input  wire        memwb_reg_write,
    // Forwarding mux selects
    output wire [1:0]  fwd_a_sel,
    output wire [1:0]  fwd_b_sel
);
    // EX-EX forwarding takes priority over MEM-EX forwarding
    assign fwd_a_sel = (exmem_reg_write && exmem_rd_addr != 5'h0 && exmem_rd_addr == idex_rs1_addr) ? 2'b01 :
                       (memwb_reg_write && memwb_rd_addr != 5'h0 && memwb_rd_addr == idex_rs1_addr) ? 2'b10 :
                                                                                                       2'b00;
    assign fwd_b_sel = (exmem_reg_write && exmem_rd_addr != 5'h0 && exmem_rd_addr == idex_rs2_addr) ? 2'b01 :
                       (memwb_reg_write && memwb_rd_addr != 5'h0 && memwb_rd_addr == idex_rs2_addr) ? 2'b10 :
                                                                                                       2'b00;
endmodule

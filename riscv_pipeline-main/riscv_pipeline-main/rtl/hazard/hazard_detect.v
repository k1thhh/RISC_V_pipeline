// =============================================================================
// hazard_detect.v — Standalone Load-Use Hazard Detection Unit
//
// NOTE: riscv_top.v uses hazard_unit.v (the combined hazard+forward module).
//       This standalone module is provided for unit testing only.
//
// Detects the load-use data hazard:
//   A load instruction is in EX (idex_mem_read=1) and the immediately
//   following instruction (in ID) reads the same register (ifid_rs1/rs2).
//   Because memory data arrives only after MEM, forwarding alone cannot
//   fix this — a 1-cycle stall must be inserted.
//
// Fix applied (was comparing idex_rd against idex_rs1/rs2 — wrong!):
//   Must compare the load's destination (idex_rd) against the ID
//   instruction's source registers (ifid_rs1, ifid_rs2).
// =============================================================================

module hazard_detect (
    // ID stage source registers (the instruction that needs the loaded value)
    input  wire [4:0] ifid_rs1_addr,
    input  wire [4:0] ifid_rs2_addr,
    // EX stage load instruction
    input  wire [4:0] idex_rd_addr,
    input  wire       idex_mem_read,
    // Control hazard flush (branch_taken from branch_unit)
    input  wire       branch_taken,
    output wire       stall,
    output wire       flush
);
    // Load-use: load is in EX, consumer is in ID.
    // Compare load's rd against ID instruction's rs1 and rs2.
    assign stall = idex_mem_read &&
                   ((idex_rd_addr == ifid_rs1_addr) || (idex_rd_addr == ifid_rs2_addr)) &&
                   (idex_rd_addr != 5'h0);

    assign flush = branch_taken;

endmodule

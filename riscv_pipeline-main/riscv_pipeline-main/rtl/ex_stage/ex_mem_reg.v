//=============================================================================
// rtl/ex_stage/ex_mem_reg.v
// EX/MEM Pipeline Register — "The Bridge Between Execute and Memory"
// =============================================================================
//
// What does this module do?
//   It's a set of flip‑flops that capture the results of the EX stage
//   and hold them for the MEM stage on the next clock cycle.
//   Think of it as a one‑clock delay line for all the signals that need
//   to travel from ALU/execution into the data memory and beyond.
//
// Why do we need this module?
//   In our 5‑stage pipeline, each stage works on a different instruction.
//   The EX stage produces an ALU result, memory control flags, and a
//   destination register address.  The MEM stage needs those values
//   exactly one cycle later.  This register provides that storage.
//
// Does it handle stalls/flushes?
//   No — pipeline stalls and flushes are applied only to the earlier
//   registers (IF/ID and ID/EX).  By the time an instruction reaches
//   EX/MEM, we know it will complete; memory accesses and writes
//   are never cancelled.  So this register always loads new values
//   on every clock (unless reset).
//
// =============================================================================

module ex_mem_reg (
    input  wire        clk,            // Global clock
    input  wire        rst,            // Synchronous reset (active high)

    // ============ Inputs: from the EX stage ===================================
    input  wire [31:0] idex_pc_plus4,   // PC + 4 from ID/EX, needed for JAL link address
    input  wire [31:0] alu_result_E,    // 32‑bit result from the ALU
    input  wire [31:0] rs2_data_fwd,    // Value of rs2 after forwarding, used for stores
    input  wire [4:0]  idex_rd_addr,    // Destination register index (5 bits)
    input  wire        alu_zero_E,      // ALU zero flag (1 if result == 0)
    input  wire        idex_reg_write,  // Will this instruction write a register?
    input  wire        idex_mem_read,   // Is this a load instruction?
    input  wire        idex_mem_write,  // Is this a store instruction?
    input  wire [1:0]  idex_mem_to_reg, // Selects WB source: 00=ALU, 01=mem, 10=PC+4
    input  wire        idex_branch,     // Branch instruction flag (not used in MEM)
    input  wire        idex_jump,       // Jump instruction flag (not used in MEM)
    input  wire [2:0]  idex_funct3,     // funct3 field, mostly for load/store size

    // ============ Outputs: to the MEM stage ===================================
    output reg [31:0] exmem_pc_plus4,   // Registered PC+4, passed to MEM/WB
    output reg [31:0] exmem_alu_result, // Registered ALU result (used as memory address or data)
    output reg [31:0] exmem_rs2_data,   // Registered store data
    output reg [4:0]  exmem_rd_addr,    // Registered destination register
    output reg        exmem_zero,       // Registered zero flag (unused after EX, but saved)
    output reg        exmem_reg_write,  // Registered reg write enable
    output reg        exmem_mem_read,   // Registered memory read enable
    output reg        exmem_mem_write,  // Registered memory write enable
    output reg [1:0]  exmem_mem_to_reg, // Registered WB source select
    output reg        exmem_branch,     // Registered branch flag (unused after EX)
    output reg        exmem_jump,       // Registered jump flag (unused after EX)
    output reg [2:0]  exmem_funct3      // Registered funct3, used by data_mem & load_extend
);

    // ==========================================================================
    // The actual flip‑flops: an always block that updates on every posedge clock
    // ==========================================================================
    always @(posedge clk) begin
        if (rst) begin
            // Reset: clear all outputs to safe default values.
            //   ALU result -> 0
            //   store data  -> 0
            //   destination -> register x0 (which is hardwired to 0)
            //   all control signals -> inactive
            exmem_pc_plus4   <= 32'h0;
            exmem_alu_result <= 32'h0;
            exmem_rs2_data   <= 32'h0;
            exmem_rd_addr    <= 5'h0;     // x0
            exmem_zero       <= 1'b0;
            exmem_reg_write  <= 1'b0;     // no write
            exmem_mem_read   <= 1'b0;     // no load
            exmem_mem_write  <= 1'b0;     // no store
            exmem_mem_to_reg <= 2'b00;    // ALU result selected (don't care)
            exmem_branch     <= 1'b0;
            exmem_jump       <= 1'b0;
            exmem_funct3     <= 3'h0;

        end else begin
            // Normal operation: capture all inputs from the EX stage.
            // Each output gets the value that was present at the input
            // just before the clock edge.  This creates the EX/MEM
            // pipeline boundary.
            exmem_pc_plus4   <= idex_pc_plus4;   // PC+4 moves forward
            exmem_alu_result <= alu_result_E;    // ALU result for memory addr or WB
            exmem_rs2_data   <= rs2_data_fwd;    // correct store data (after forwarding)
            exmem_rd_addr    <= idex_rd_addr;    // remember which register to write
            exmem_zero       <= alu_zero_E;      // save zero flag (unused later)
            exmem_reg_write  <= idex_reg_write;  // pass on the write enable
            exmem_mem_read   <= idex_mem_read;   // tell MEM: we are reading
            exmem_mem_write  <= idex_mem_write;  // tell MEM: we are writing
            exmem_mem_to_reg <= idex_mem_to_reg; // tell WB mux what to select
            exmem_branch     <= idex_branch;     // forward branch flag (unused)
            exmem_jump       <= idex_jump;       // forward jump flag (unused)
            exmem_funct3     <= idex_funct3;     // needed for byte/halfword/word
        end
    end

endmodule

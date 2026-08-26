// rtl/mem_stage/mem_wb_reg.v — MEM/WB Pipeline Register
// =============================================================================
//
// This register sits between the MEM and WB stages. It captures:
//   – The ALU result (which might be the final value for most instructions)
//   – The data read from memory (already sign/zero‑extended by load_extend)
//   – PC+4, needed for JAL/JALR link address
//   – Destination register index and write‑enable
//   – The mem_to_reg control signal that tells the WB mux what to pick
//

// No stalls or flushes are ever applied to the MEM/WB register, so it
// simply loads new values on every rising clock edge (except during reset).
// =============================================================================

module mem_wb_reg (
    input  wire        clk,              // Global clock
    input  wire        rst,              // Synchronous reset (active high)

    // Inputs from the MEM stage
    input  wire [31:0] i_pc_plus4,      // PC+4 (for JAL link)
    input  wire [31:0] i_alu_result,    // ALU result from EX stage (just passed through MEM)
    input  wire [31:0] i_mem_rdata,     // Data from memory, after load_extend
    input  wire [4:0]  i_rd_addr,       // Destination register number
    input  wire        i_reg_write,     // Register file write enable
    input  wire [1:0]  i_mem_to_reg,    // WB source select: 00=ALU, 01=mem, 10=PC+4

    // Outputs to the WB stage
    output reg [31:0] o_pc_plus4,
    output reg [31:0] o_alu_result,
    output reg [31:0] o_mem_rdata,
    output reg [4:0]  o_rd_addr,
    output reg        o_reg_write,
    output reg [1:0]  o_mem_to_reg
);

    // ==========================================================================
    // The actual register update
    // ==========================================================================
    always @(posedge clk) begin
        if (rst) begin
            // When reset is asserted, clear all outputs to safe values.
            // Destination register set to x0 (hardwired to 0), write disabled.
            o_pc_plus4   <= 32'h0;
            o_alu_result <= 32'h0;
            o_mem_rdata  <= 32'h0;
            o_rd_addr    <= 5'h0;        // x0
            o_reg_write  <= 1'b0;        // no write
            o_mem_to_reg <= 2'b00;       // don't care, but default to ALU result
        end else begin
            // Normal operation: pass all inputs to the outputs.
            // The WB stage will use these values on the next clock cycle.
            o_pc_plus4   <= i_pc_plus4;
            o_alu_result <= i_alu_result;
            o_mem_rdata  <= i_mem_rdata;
            o_rd_addr    <= i_rd_addr;
            o_reg_write  <= i_reg_write;
            o_mem_to_reg <= i_mem_to_reg;
        end
    end

endmodule

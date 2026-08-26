// =============================================================================
// if_id_reg.v — IF/ID Pipeline Register (Standalone Module)
//
// NOTE: riscv_top.v inlines the IF/ID register logic. This standalone module
//       is provided for integration testing only.
//
// Captures three values from the IF stage:
//   - pc       : address of the fetched instruction
//   - pc_plus4 : PC + 4 (needed for JAL/JALR link address writeback)
//   - instr    : the 32-bit fetched instruction word
//
// Control:
//   - rst  : synchronous reset → inject NOP (addi x0,x0,0)
//   - clr  : flush → inject NOP (control hazard: branch/jump taken)
//   - en   : enable → 1=run, 0=stall (hold current values)
// =============================================================================

module if_id_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,       // Enable: 1=run, 0=stall (hold values)
    input  wire        clr,      // Flush: 1=inject NOP (branch taken)

    // Inputs from the IF stage
    input  wire [31:0] pc_f,
    input  wire [31:0] pc_plus4_f,
    input  wire [31:0] instr_f,

    // Outputs to the ID stage
    output reg  [31:0] pc_d,
    output reg  [31:0] pc_plus4_d,
    output reg  [31:0] instr_d
);

    always @(posedge clk) begin
        if (rst) begin
            pc_d       <= 32'h00000000;
            pc_plus4_d <= 32'h00000000;
            instr_d    <= 32'h00000013; // NOP: addi x0, x0, 0
        end
        else if (clr) begin
            // Wrong branch path fetched — flush by injecting NOP
            pc_d       <= 32'h00000000;
            pc_plus4_d <= 32'h00000000;
            instr_d    <= 32'h00000013; // NOP: addi x0, x0, 0
        end
        else if (en) begin
            // Normal operation: latch all three IF values
            pc_d       <= pc_f;
            pc_plus4_d <= pc_plus4_f;
            instr_d    <= instr_f;
        end
        // en == 0: stall — hold all fields unchanged (implicit)
    end

endmodule

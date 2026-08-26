// =============================================================================
// alu.v — 32-bit RV32I ALU
// Spec ref: rv32i_top_spec.md §6.4 | README §rtl/ex_stage/alu.v
//
// Inputs
// ------
//   operand_a [31:0] : rs1 data (after forwarding mux)
//   operand_b [31:0] : rs2 data or sign-extended immediate (after src mux)
//   ALUControl [3:0] : operation select from alu_decoder.v
//
// Outputs
// -------
//   result   [31:0] : computed value
//   Zero            : result == 0   (used by branch_unit for BEQ/BNE)
//   Negative        : result[31]    (MSB of signed result, used for BLT/BGE)
//   Carry           : unsigned carry-out of bit 31 (used for BLTU/BGEU)
//   Overflow        : signed two's-complement overflow (used for BLT/BGE)
//
// Flag semantics (two's complement signed)
// -----------------------------------------
//   BEQ  : Zero
//   BNE  : ~Zero
//   BLT  : Negative ^ Overflow          (signed less-than after SUB)
//   BGE  : ~(Negative ^ Overflow)
//   BLTU : ~Carry                       (borrow = ~carry for unsigned SUB)
//   BGEU : Carry
//
// ALUControl encoding (matches rv32i_top_spec.md §7.1)
//   4'b0000  ADD
//   4'b0001  SUB
//   4'b0010  AND
//   4'b0011  OR
//   4'b0100  XOR
//   4'b0101  SLL
//   4'b0110  SRL
//   4'b0111  SRA
//   4'b1000  SLT   (signed)
//   4'b1001  SLTU  (unsigned)
//   4'b1010  PASS_B (LUI: rd = U-imm)
//   4'b1111  NOP   (output 0)
// =============================================================================

module alu (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [3:0]  ALUControl,

    output reg  [31:0] result,
    output wire        Zero,
    output wire        Negative,
    output wire        Carry,
    output wire        Overflow
);

    // -------------------------------------------------------------------------
    // Adder / Subtractor — shared by ADD, SUB, SLT, SLTU, and branch compares
    // Use a 33-bit adder: bit 32 is the carry-out.
    // For SUB: compute A + (~B) + 1  (two's complement negation)
    // -------------------------------------------------------------------------
    wire        do_sub;
    wire [32:0] adder_a;
    wire [32:0] adder_b;
    wire [32:0] adder_result;

    assign do_sub       = (ALUControl == 4'b0001) ||   // SUB
                          (ALUControl == 4'b1000) ||   // SLT
                          (ALUControl == 4'b1001);     // SLTU

    assign adder_a      = {1'b0, operand_a};
    assign adder_b      = do_sub ? {1'b0, ~operand_b} : {1'b0, operand_b};
    assign adder_result = adder_a + adder_b + (do_sub ? 33'd1 : 33'd0);

    // Signed overflow: occurs when the signs of both operands are the same
    // and the sign of the result differs.
    wire sum_overflow;
    assign sum_overflow = (~operand_a[31] & ~adder_b[31] &  adder_result[31]) |
                          ( operand_a[31] &  adder_b[31] & ~adder_result[31]);

    // -------------------------------------------------------------------------
    // Shift amount — RV32I uses only the lower 5 bits of operand_b
    // -------------------------------------------------------------------------
    wire [4:0] shamt;
    assign shamt = operand_b[4:0];

    // -------------------------------------------------------------------------
    // Result mux
    // -------------------------------------------------------------------------
    always @(*) begin
        case (ALUControl)
            4'b0000: result = adder_result[31:0];                    // ADD
            4'b0001: result = adder_result[31:0];                    // SUB
            4'b0010: result = operand_a & operand_b;                 // AND
            4'b0011: result = operand_a | operand_b;                 // OR
            4'b0100: result = operand_a ^ operand_b;                 // XOR
            4'b0101: result = operand_a << shamt;                    // SLL
            4'b0110: result = operand_a >> shamt;                    // SRL (logical)
            4'b0111: result = $signed(operand_a) >>> shamt;          // SRA (arithmetic)
            4'b1000: result = {31'b0, sum_overflow ^ adder_result[31]}; // SLT  (signed)
            4'b1001: result = {31'b0, ~adder_result[32]};            // SLTU (unsigned borrow)
            4'b1010: result = operand_b;                             // PASS_B (LUI)
            4'b1111: result = 32'h0;                                 // NOP
            default: result = 32'h0;
        endcase
    end

    // -------------------------------------------------------------------------
    // Flag outputs (driven from the shared adder and result)
    // -------------------------------------------------------------------------
    assign Zero     = (result == 32'h0);
    assign Negative = result[31];
    assign Carry    = adder_result[32];      // unsigned carry-out
    assign Overflow = sum_overflow;

endmodule

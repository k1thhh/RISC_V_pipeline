// =============================================================================
// alu_decoder.v — ALU Control Decoder
// Spec ref: rv32i_top_spec.md §7.1 | README §rtl/control/
// Combines opcode, funct3, and funct7[5] to produce ALUControl[3:0].
// ALUControl encoding matches the spec table in rv32i_top_spec.md §7.1:
//
//   4'b0000  ADD    — R-add, I-arith, loads, stores, AUIPC (base+offset)
//   4'b0001  SUB    — R-sub, branch comparisons (feed result to branch_unit)
//   4'b0010  AND
//   4'b0011  OR
//   4'b0100  XOR
//   4'b0101  SLL    — shift left logical
//   4'b0110  SRL    — shift right logical
//   4'b0111  SRA    — shift right arithmetic
//   4'b1000  SLT    — set less than (signed)
//   4'b1001  SLTU   — set less than (unsigned)
//   4'b1010  PASS_B — pass operand B through (LUI: rd = U-imm)
//   4'b1111  NOP    — bubble / unknown
//
// Inputs
// ------
//   opcode   [6:0]  : from instruction [6:0]
//   funct3   [2:0]  : from instruction [14:12]
//   funct7b5 [0]    : instruction[30] — distinguishes ADD/SUB and SRL/SRA
//
// The README notes only funct7[5] (bit 30) is needed, not full funct7[6:0].
// =============================================================================

module alu_decoder (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       funct7b5,     // instruction[30]

    output reg  [3:0] ALUControl
);

    localparam OP_R       = 7'b0110011;
    localparam OP_I_ARITH = 7'b0010011;
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_JALR    = 7'b1100111;
    localparam OP_LUI     = 7'b0110111;
    localparam OP_AUIPC   = 7'b0010111;

    always @(*) begin
        ALUControl = 4'b1111; // default: NOP

        case (opcode)

            // -----------------------------------------------------------------
            // Loads and Stores — always ADD (address = rs1 + imm)
            // -----------------------------------------------------------------
            OP_LOAD,
            OP_STORE: ALUControl = 4'b0000; // ADD

            // -----------------------------------------------------------------
            // JAL / JALR — ALU is not used for target (branch_unit handles it)
            // Drive ADD so the ALU output is harmless if someone reads it
            // -----------------------------------------------------------------
            OP_JAL,
            OP_JALR:  ALUControl = 4'b0000; // ADD (result discarded)

            // -----------------------------------------------------------------
            // AUIPC — ALU computes PC + U-imm  (ADD)
            // LUI   — ALU passes imm through   (PASS_B)
            // -----------------------------------------------------------------
            OP_AUIPC: ALUControl = 4'b0000; // ADD  (operand A = PC from branch_unit)
            OP_LUI:   ALUControl = 4'b1010; // PASS_B

            // -----------------------------------------------------------------
            // B-type branches — ALU subtracts rs1 - rs2 to set flags;
            // branch_unit evaluates the condition from those flags.
            // -----------------------------------------------------------------
            OP_BRANCH: ALUControl = 4'b0001; // SUB (flags → branch_unit)

            // -----------------------------------------------------------------
            // R-type — decoded by funct3 + funct7b5
            // -----------------------------------------------------------------
            OP_R: begin
                case (funct3)
                    3'b000: ALUControl = funct7b5 ? 4'b0001 : 4'b0000; // SUB / ADD
                    3'b001: ALUControl = 4'b0101; // SLL
                    3'b010: ALUControl = 4'b1000; // SLT
                    3'b011: ALUControl = 4'b1001; // SLTU
                    3'b100: ALUControl = 4'b0100; // XOR
                    3'b101: ALUControl = funct7b5 ? 4'b0111 : 4'b0110; // SRA / SRL
                    3'b110: ALUControl = 4'b0011; // OR
                    3'b111: ALUControl = 4'b0010; // AND
                    default: ALUControl = 4'b1111;
                endcase
            end

            // -----------------------------------------------------------------
            // I-type arithmetic — funct3 only; funct7b5 gates SRAI vs SRLI
            // -----------------------------------------------------------------
            OP_I_ARITH: begin
                case (funct3)
                    3'b000: ALUControl = 4'b0000; // ADDI
                    3'b001: ALUControl = 4'b0101; // SLLI  (funct7b5 must be 0)
                    3'b010: ALUControl = 4'b1000; // SLTI
                    3'b011: ALUControl = 4'b1001; // SLTIU
                    3'b100: ALUControl = 4'b0100; // XORI
                    3'b101: ALUControl = funct7b5 ? 4'b0111 : 4'b0110; // SRAI / SRLI
                    3'b110: ALUControl = 4'b0011; // ORI
                    3'b111: ALUControl = 4'b0010; // ANDI
                    default: ALUControl = 4'b1111;
                endcase
            end

            default: ALUControl = 4'b1111; // NOP / bubble
        endcase
    end

endmodule

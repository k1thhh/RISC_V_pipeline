// =============================================================================
// imm_gen.v — Immediate Generator
// Stage: ID (purely combinational)
//
// Extracts and sign-extends the immediate value based on RV32I instruction
// format: I, S, B, U, J-type.  R-type and unknown opcodes output 0.
// =============================================================================

module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);
    wire [6:0] opcode = instr[6:0];

    localparam OP_I_ARITH = 7'b0010011;
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_JALR    = 7'b1100111;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_LUI     = 7'b0110111;
    localparam OP_AUIPC   = 7'b0010111;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_FENCE   = 7'b0001111;
    localparam OP_SYSTEM  = 7'b1110011;

    always @(*) begin
        case (opcode)
            // I-type: loads, JALR, arithmetic immediates
            OP_I_ARITH,
            OP_LOAD,
            OP_JALR:  imm = {{20{instr[31]}}, instr[31:20]};

            // S-type: stores
            OP_STORE: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type: branches
            OP_BRANCH: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            // U-type: LUI, AUIPC
            OP_LUI,
            OP_AUIPC: imm = {instr[31:12], 12'b0};

            // J-type: JAL
            OP_JAL:   imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            // FENCE and SYSTEM (ECALL/EBREAK) — no immediate needed; output 0
            OP_FENCE,
            OP_SYSTEM: imm = 32'h0;

            // R-type and unknown: no immediate
            default:  imm = 32'h0;
        endcase
    end

endmodule

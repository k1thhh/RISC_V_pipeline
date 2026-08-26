// =============================================================================
// branch_unit.v — Branch and Jump Resolution Unit
// Stage: EX (combinational)
//
// Handles all branch and jump decisions:
//   BEQ, BNE, BLT, BGE, BLTU, BGEU  (conditional branches)
//   JAL                               (unconditional, PC-relative)
//   JALR                              (unconditional, register-relative)
//
// JALR vs JAL identification:
//   jump=1 && alu_src=1 → JALR (target = rs1 + imm, LSB cleared)
//   jump=1 && alu_src=0 → JAL  (target = PC + imm)
//
// Branch penalty: branch/jump is resolved in EX → 2-cycle flush penalty
//   (IF and ID stages are squashed when branch_taken=1)
// =============================================================================

module branch_unit (
    // Data inputs (after forwarding)
    input  wire [31:0] rs1_data,      // rs1 value (after forwarding mux)
    input  wire [31:0] rs2_data,      // rs2 value (after forwarding mux)
    input  wire [31:0] pc,            // Current PC (from ID/EX register)
    input  wire [31:0] pc_plus4,      // PC+4 (for link address — not used here)
    input  wire [31:0] imm,           // Sign-extended immediate

    // Control inputs
    input  wire [2:0]  funct3,        // Branch type selector
    input  wire        branch,        // 1 = this is a B-type branch
    input  wire        jump,          // 1 = this is JAL or JALR
    input  wire        alu_src,       // 1 = JALR (imm-based target), 0 = JAL

    // Outputs
    output reg         branch_taken,  // 1 = redirect the PC to branch_target
    output reg  [31:0] branch_target  // Target address to jump to
);

    // -------------------------------------------------------------------------
    // Step 1: Evaluate branch condition directly from register values.
    //         Comparisons are done inline rather than using ALU flags so
    //         that the branch unit is self-contained.
    // -------------------------------------------------------------------------
    reg branch_cond;

    always @(*) begin
        case (funct3)
            3'b000: branch_cond = (rs1_data == rs2_data);                    // BEQ
            3'b001: branch_cond = (rs1_data != rs2_data);                    // BNE
            3'b100: branch_cond = ($signed(rs1_data) <  $signed(rs2_data));  // BLT
            3'b101: branch_cond = ($signed(rs1_data) >= $signed(rs2_data));  // BGE
            3'b110: branch_cond = (rs1_data <  rs2_data);                    // BLTU
            3'b111: branch_cond = (rs1_data >= rs2_data);                    // BGEU
            default: branch_cond = 1'b0;
        endcase
    end

    // -------------------------------------------------------------------------
    // Step 2: Determine whether to redirect the PC.
    // -------------------------------------------------------------------------
    always @(*) begin
        branch_taken = (branch & branch_cond) | jump;
    end

    // -------------------------------------------------------------------------
    // Step 3: Compute the target address.
    //   JALR : rs1 + imm, with LSB forced to 0 (RV32I spec §2.5)
    //   JAL  : PC + J-imm
    //   B-type: PC + B-imm  (same adder as JAL)
    // -------------------------------------------------------------------------
    always @(*) begin
        if (jump && alu_src)
            branch_target = (rs1_data + imm) & 32'hFFFFFFFE;  // JALR
        else
            branch_target = pc + imm;                          // JAL or branch
    end

endmodule
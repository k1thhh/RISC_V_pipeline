// =============================================================================
// control_unit.v — Control Unit Wrapper
// Wraps main_decoder + alu_decoder into the interface used by riscv_top.v
// =============================================================================

module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output wire [3:0] alu_op,
    output wire       alu_src,
    output wire       reg_write,
    output wire       mem_read,
    output wire       mem_write,
    output wire [1:0] mem_to_reg,
    output wire       branch,
    output wire       jump,
    output wire       trap,    // 1 = ECALL/EBREAK — use to halt or invoke trap handler
    output wire       auipc,   // 1 = AUIPC: EX must use PC as ALU operand_a
    output wire [2:0] imm_src  // Immediate format (see main_decoder.v for encoding)
                               // Available for connection to imm_gen if desired
);

    main_decoder MDEC (
        .opcode    (opcode),
        .RegWrite  (reg_write),
        .ALUSrc    (alu_src),
        .MemRead   (mem_read),
        .MemWrite  (mem_write),
        .Branch    (branch),
        .Jump      (jump),
        .Trap      (trap),
        .ResultSrc (mem_to_reg),
        .ImmSrc    (imm_src),
        .AuiPC     (auipc)
    );

    alu_decoder ADEC (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7b5   (funct7[5]),
        .ALUControl (alu_op)
    );

endmodule

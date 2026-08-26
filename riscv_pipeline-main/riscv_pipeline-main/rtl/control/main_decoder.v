// =============================================================================
// main_decoder.v — Main Control Decoder
// Spec ref: rv32i_top_spec.md §6.5 | README §rtl/control/
//
// Decodes the 7-bit opcode into all datapath control signals.
// ALUControl is NOT produced here — see alu_decoder.v.
//
// Output signal semantics
// -----------------------
//  RegWrite  : 1 = write result to register file at WB
//  ALUSrc    : 0 = operand B from rs2, 1 = from sign-extended immediate
//  MemRead   : 1 = data memory read enable (load instructions)
//  MemWrite  : 1 = data memory write enable (store instructions)
//  Branch    : 1 = instruction is a B-type branch
//  Jump      : 1 = instruction is JAL or JALR
//  Trap      : 1 = instruction triggers a trap (ECALL, EBREAK)
//               Can be used to halt simulation or invoke a trap handler.
//  ResultSrc : WB mux select (spec §7.2)
//               2'b00 = ALU result
//               2'b01 = memory read data
//               2'b10 = PC + 4  (JAL / JALR link address)
//  ImmSrc    : immediate format selector for imm_gen.v
//               3'b000 = I-type
//               3'b001 = S-type
//               3'b010 = B-type
//               3'b011 = U-type
//               3'b100 = J-type
//               3'b101 = R-type (no immediate; imm_gen outputs 0)
//  AuiPC     : 1 for AUIPC: EX stage must use pipelined PC as ALU operand A
// =============================================================================

module main_decoder (
    input  wire [6:0] opcode,

    output reg        RegWrite,
    output reg        ALUSrc,
    output reg        MemRead,
    output reg        MemWrite,
    output reg        Branch,
    output reg        Jump,
    output reg        Trap,       // ECALL / EBREAK trap signal
    output reg [1:0]  ResultSrc,
    output reg [2:0]  ImmSrc,
    output reg        AuiPC      // 1 for AUIPC: ALU operand_a must be PC, not rs1
);

    // RV32I opcode map (spec vol I §2.2)
    localparam OP_R      = 7'b0110011; // R-type  : ADD SUB SLL ... AND
    localparam OP_I_ARITH= 7'b0010011; // I-type  : ADDI SLTI ... SRAI
    localparam OP_LOAD   = 7'b0000011; // I-type  : LB LH LW LBU LHU
    localparam OP_STORE  = 7'b0100011; // S-type  : SB SH SW
    localparam OP_BRANCH = 7'b1100011; // B-type  : BEQ BNE BLT BGE BLTU BGEU
    localparam OP_JAL    = 7'b1101111; // J-type  : JAL
    localparam OP_JALR   = 7'b1100111; // I-type  : JALR
    localparam OP_LUI    = 7'b0110111; // U-type  : LUI
    localparam OP_AUIPC  = 7'b0010111; // U-type  : AUIPC
    localparam OP_FENCE  = 7'b0001111; // FENCE / FENCE.I — memory ordering hint
    localparam OP_SYSTEM = 7'b1110011; // ECALL / EBREAK

    always @(*) begin
        // Safe defaults — prevents latches and makes bubbles safe
        RegWrite  = 1'b0;
        ALUSrc    = 1'b0;
        MemRead   = 1'b0;
        MemWrite  = 1'b0;
        Branch    = 1'b0;
        Jump      = 1'b0;
        Trap      = 1'b0;
        ResultSrc = 2'b00;
        ImmSrc    = 3'b000;
        AuiPC     = 1'b0;

        case (opcode)

            OP_R: begin
                // ADD SUB SLL SLT SLTU XOR SRL SRA OR AND
                RegWrite  = 1'b1;
                ALUSrc    = 1'b0;   // operand B = rs2
                ResultSrc = 2'b00;  // write back ALU result
                ImmSrc    = 3'b101; // R-type: no immediate
            end

            OP_I_ARITH: begin
                // ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;   // operand B = immediate
                ResultSrc = 2'b00;
                ImmSrc    = 3'b000; // I-type immediate
            end

            OP_LOAD: begin
                // LB LH LW LBU LHU
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;   // address = rs1 + I-imm
                MemRead   = 1'b1;
                ResultSrc = 2'b01;  // write back memory data
                ImmSrc    = 3'b000; // I-type immediate
            end

            OP_STORE: begin
                // SB SH SW
                RegWrite  = 1'b0;
                ALUSrc    = 1'b1;   // address = rs1 + S-imm
                MemWrite  = 1'b1;
                ResultSrc = 2'b00;  // irrelevant (no WB), keep default
                ImmSrc    = 3'b001; // S-type immediate
            end

            OP_BRANCH: begin
                // BEQ BNE BLT BGE BLTU BGEU
                RegWrite  = 1'b0;
                ALUSrc    = 1'b0;   // compare rs1 vs rs2
                Branch    = 1'b1;
                ResultSrc = 2'b00;  // irrelevant
                ImmSrc    = 3'b010; // B-type immediate
            end

            OP_JAL: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b0;   // target computed by branch_unit
                Jump      = 1'b1;
                ResultSrc = 2'b10;  // write back PC+4 (link address)
                ImmSrc    = 3'b100; // J-type immediate
            end

            OP_JALR: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;   // target = rs1 + I-imm (in branch_unit)
                Jump      = 1'b1;
                ResultSrc = 2'b10;  // write back PC+4
                ImmSrc    = 3'b000; // I-type immediate
            end

            OP_LUI: begin
                // rd = U-immediate (upper 20 bits, lower 12 zeroed)
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;
                ResultSrc = 2'b00;
                ImmSrc    = 3'b011; // U-type immediate
            end

            OP_AUIPC: begin
                // rd = PC + U-immediate; ALU computes ADD with operand_a = PC
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;
                ResultSrc = 2'b00;
                ImmSrc    = 3'b011; // U-type immediate
                AuiPC     = 1'b1;   // signal EX to use idex_pc as operand_a
            end

            OP_FENCE: begin
                // FENCE / FENCE.I — memory ordering hint.
                // In this single-issue, in-order pipeline with no cache, all
                // stores are globally visible before the next instruction anyway.
                // Treated as NOP; no datapath action required.
                RegWrite  = 1'b0;
            end

            OP_SYSTEM: begin
                // ECALL / EBREAK — raise a trap.
                // Trap signal can be used by riscv_top to halt or redirect to
                // a trap handler. No register write or memory access.
                Trap      = 1'b1;
            end

            default: begin
                // Unknown opcode — all signals deasserted (NOP behaviour)
                RegWrite  = 1'b0;
            end

        endcase
    end

endmodule

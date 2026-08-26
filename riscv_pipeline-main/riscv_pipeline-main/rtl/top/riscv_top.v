// =============================================================================
// riscv_top.v — RV32I 5-Stage Pipelined Processor Top-Level
// Version  : 0.2
// Spec ref : rv32i_top_spec.md §4-8
//
// Instantiation order mirrors datapath left-to-right:
//   IF → IF/ID reg → ID → ID/EX reg → EX → EX/MEM reg → MEM → MEM/WB reg → WB
// Hazard/Forwarding unit sits beside ID/EX and drives stall + fwd muxes.
//
// Halt conditions (PC freezes permanently):
//   1. EBREAK (0x00100073) — standard RISC-V breakpoint / simulation exit
//   2. Sentinel 0xFFFFFFFF — non-standard convenience sentinel for simulation
// =============================================================================

module riscv_top (
    input  wire        clk,
    input  wire        rst,

    // Debug / observation outputs
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instr,
    output wire [31:0] debug_alu_result,

    // Register write-back observation
    output wire [31:0] debug_wb_data,
    output wire [4:0]  debug_wb_rd,
    output wire        debug_wb_valid,

    // Pipeline control observation
    output wire        debug_stall,
    output wire        debug_flush,
    output wire        debug_branch_taken,
    output wire        debug_halt,

    // Data-memory observation
    output wire        debug_mem_read,
    output wire        debug_mem_write,
    output wire [31:0] debug_mem_addr,
    output wire [31:0] debug_mem_wdata,
    output wire [31:0] debug_mem_rdata,
    output wire        debug_mem_misaligned
);

// =============================================================================
// 0.  HAZARD / FORWARD CONTROL (declared early; driven by hazard_unit below)
// =============================================================================

    wire        stall;          // Freeze PC + IF/ID; bubble into ID/EX
    wire        flush;          // Squash IF/ID + ID/EX on taken branch/jump
    wire [1:0]  fwd_a_sel;     // Forwarding mux for ALU operand A
    wire [1:0]  fwd_b_sel;     // Forwarding mux for ALU operand B
    wire        halt;           // PC freeze when HALT/EBREAK instruction is fetched

// =============================================================================
// 1.  IF STAGE
// =============================================================================

    // --- PC logic ---
    wire [31:0] pcF;
    wire [31:0] pcPlus4F;
    wire [31:0] pcNextF;
    wire        branch_taken;   // From EX (branch_unit)
    wire [31:0] branch_target;  // From EX (branch_unit)

    assign pcPlus4F = pcF + 32'd4;
    assign pcNextF  = branch_taken ? branch_target : pcPlus4F;

    // Halt: freeze PC permanently on EBREAK or the simulation sentinel.
    // instrF is combinational (IMEM output), so halt is valid the same cycle.
    wire [31:0] instrF;
    assign halt = (instrF == 32'h00100073) ||   // EBREAK (standard)
                  (instrF == 32'hFFFFFFFF);      // simulation sentinel (legacy)

    pc_reg PC_REG (
        .clk     (clk),
        .rst     (rst),
        .en      (~stall & ~halt),
        .pc_next (pcNextF),
        .pc      (pcF)
    );

    // --- Instruction memory ---
    instr_mem IMEM (
        .pc    (pcF),
        .instr (instrF)
    );

// =============================================================================
// 2.  IF/ID PIPELINE REGISTER  (spec §5.1)
// =============================================================================

    reg [31:0] ifid_pc;
    reg [31:0] ifid_pc_plus4;
    reg [31:0] ifid_instr;

    always @(posedge clk) begin
        if (rst || flush) begin
            ifid_pc       <= 32'h0;
            ifid_pc_plus4 <= 32'h0;
            ifid_instr    <= 32'h00000013; // NOP: addi x0, x0, 0
        end else if (!stall) begin
            ifid_pc       <= pcF;
            ifid_pc_plus4 <= pcPlus4F;
            ifid_instr    <= instrF;
        end
        // stall: hold all fields unchanged (implicit — no else branch)
    end

// =============================================================================
// 3.  ID STAGE
// =============================================================================

    // --- Field extraction from instruction ---
    wire [6:0]  opcode      = ifid_instr[6:0];
    wire [2:0]  funct3      = ifid_instr[14:12];
    wire [6:0]  funct7      = ifid_instr[31:25];
    wire [4:0]  rs1_addr_D  = ifid_instr[19:15];
    wire [4:0]  rs2_addr_D  = ifid_instr[24:20];
    wire [4:0]  rd_addr_D   = ifid_instr[11:7];

    // --- Immediate generator ---
    wire [31:0] immD;

    imm_gen IMM_GEN (
        .instr (ifid_instr),
        .imm   (immD)
    );

    // --- Control unit (spec §6.5) ---
    wire [3:0]  alu_op_D;
    wire        alu_src_D;
    wire        reg_write_D;
    wire        mem_read_D;
    wire        mem_write_D;
    wire [1:0]  mem_to_reg_D;
    wire        branch_D;
    wire        jump_D;
    wire        auipc_D;
    wire        trap_D;      // ECALL/EBREAK trap signal
    wire [2:0]  imm_src_D;  // Immediate format (available for future use)

    control_unit CTRL (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .alu_op     (alu_op_D),
        .alu_src    (alu_src_D),
        .reg_write  (reg_write_D),
        .mem_read   (mem_read_D),
        .mem_write  (mem_write_D),
        .mem_to_reg (mem_to_reg_D),
        .branch     (branch_D),
        .jump       (jump_D),
        .trap       (trap_D),
        .auipc      (auipc_D),
        .imm_src    (imm_src_D)
    );

    // --- Register file read (write port driven from WB below) ---
    wire [31:0] rf_rdata1_D;
    wire [31:0] rf_rdata2_D;
    // WB signals declared forward; driven by MEM/WB register section
    wire        wb_reg_write;
    wire [4:0]  wb_rd_addr;
    wire [31:0] wb_wdata;

    reg_file RF (
        .clk       (clk),
        .rst       (rst),
        .rs1_addr  (rs1_addr_D),
        .rs2_addr  (rs2_addr_D),
        .rdata1    (rf_rdata1_D),
        .rdata2    (rf_rdata2_D),
        .rd_addr   (wb_rd_addr),
        .wdata     (wb_wdata),
        .reg_write (wb_reg_write)
    );

// =============================================================================
// 4.  ID/EX PIPELINE REGISTER  (spec §5.2)
// =============================================================================

    reg [31:0] idex_pc;
    reg [31:0] idex_pc_plus4;
    reg [31:0] idex_rs1_data;
    reg [31:0] idex_rs2_data;
    reg [31:0] idex_imm;
    reg [4:0]  idex_rs1_addr;
    reg [4:0]  idex_rs2_addr;
    reg [4:0]  idex_rd_addr;
    reg [3:0]  idex_alu_op;
    reg        idex_alu_src;
    reg        idex_reg_write;
    reg        idex_mem_read;
    reg        idex_mem_write;
    reg [1:0]  idex_mem_to_reg;
    reg        idex_branch;
    reg        idex_jump;
    reg [2:0]  idex_funct3;
    reg        idex_auipc;

    always @(posedge clk) begin
        if (rst || flush) begin
            // Bubble: all control signals deasserted, addresses zeroed
            idex_pc         <= 32'h0;
            idex_pc_plus4   <= 32'h0;
            idex_rs1_data   <= 32'h0;
            idex_rs2_data   <= 32'h0;
            idex_imm        <= 32'h0;
            idex_rs1_addr   <= 5'h0;
            idex_rs2_addr   <= 5'h0;
            idex_rd_addr    <= 5'h0;
            idex_alu_op     <= 4'hF;   // NOP opcode (spec §7.1)
            idex_alu_src    <= 1'b0;
            idex_reg_write  <= 1'b0;
            idex_mem_read   <= 1'b0;
            idex_mem_write  <= 1'b0;
            idex_mem_to_reg <= 2'b00;
            idex_branch     <= 1'b0;
            idex_jump       <= 1'b0;
            idex_funct3     <= 3'h0;
            idex_auipc      <= 1'b0;
        end else if (stall) begin
            // Load-use stall: freeze IF/ID and PC, inject NOP bubble into EX.
            // Data fields are don't-care; killing control signals is enough.
            idex_alu_op     <= 4'hF;
            idex_reg_write  <= 1'b0;
            idex_mem_read   <= 1'b0;
            idex_mem_write  <= 1'b0;
            idex_branch     <= 1'b0;
            idex_jump       <= 1'b0;
            idex_mem_to_reg <= 2'b00;
            idex_auipc      <= 1'b0;
        end else begin
            idex_pc         <= ifid_pc;
            idex_pc_plus4   <= ifid_pc_plus4;
            idex_rs1_data   <= rf_rdata1_D;
            idex_rs2_data   <= rf_rdata2_D;
            idex_imm        <= immD;
            idex_rs1_addr   <= rs1_addr_D;
            idex_rs2_addr   <= rs2_addr_D;
            idex_rd_addr    <= rd_addr_D;
            idex_alu_op     <= alu_op_D;
            idex_alu_src    <= alu_src_D;
            idex_reg_write  <= reg_write_D;
            idex_mem_read   <= mem_read_D;
            idex_mem_write  <= mem_write_D;
            idex_mem_to_reg <= mem_to_reg_D;
            idex_branch     <= branch_D;
            idex_jump       <= jump_D;
            idex_funct3     <= funct3;
            idex_auipc      <= auipc_D;
        end
    end

// =============================================================================
// 5.  EX STAGE
// =============================================================================

    // --- Forwarding muxes (spec §7.3) ---
    // Forward sources: EX/MEM ALU result and MEM/WB writeback data
    wire [31:0] exmem_alu_result;  // declared forward; driven by EX/MEM reg
    wire [31:0] memwb_alu_result;  // declared forward; driven by MEM/WB reg
    wire [31:0] memwb_mem_data;    // declared forward; driven by MEM/WB reg
    wire [1:0]  memwb_mem_to_reg;  // declared forward

    // wb_wdata reused as forwarding source from MEM/WB stage (declared in §3)
    wire [31:0] fwd_src_a;
    wire [31:0] fwd_src_b_pre; // before alu_src mux

    assign fwd_src_a = (fwd_a_sel == 2'b01) ? exmem_alu_result :
                       (fwd_a_sel == 2'b10) ? wb_wdata          :
                                              idex_rs1_data;

    assign fwd_src_b_pre = (fwd_b_sel == 2'b01) ? exmem_alu_result :
                           (fwd_b_sel == 2'b10) ? wb_wdata          :
                                                  idex_rs2_data;

    // AUIPC: rd = PC + U-imm. Override operand A with the pipelined PC.
    // This is the single authoritative AUIPC mechanism in the design.
    wire [31:0] alu_operand_a;
    assign alu_operand_a = idex_auipc ? idex_pc : fwd_src_a;

    // ALU src B mux: register data vs immediate
    wire [31:0] alu_operand_b;
    assign alu_operand_b = idex_alu_src ? idex_imm : fwd_src_b_pre;

    // --- ALU (spec §6.4) ---
    wire [31:0] alu_result_E;
    wire        alu_zero_E;

    alu ALU (
        .operand_a  (alu_operand_a),
        .operand_b  (alu_operand_b),
        .ALUControl (idex_alu_op),
        .result     (alu_result_E),
        .Zero       (alu_zero_E)
    );

    // --- Branch and Jump Unit (spec §6.6) ---
    branch_unit BRANCH_UNIT (
        .rs1_data     (fwd_src_a),
        .rs2_data     (fwd_src_b_pre),
        .pc           (idex_pc),
        .pc_plus4     (idex_pc_plus4),
        .imm          (idex_imm),
        .funct3       (idex_funct3),
        .branch       (idex_branch),
        .jump         (idex_jump),
        .alu_src      (idex_alu_src),
        .branch_taken (branch_taken),
        .branch_target(branch_target)
    );

    // Control hazard flush: flush IF/ID and ID/EX whenever a branch/jump is taken.
    // Note: flush is driven here directly from branch_taken, NOT from hazard_unit
    //       (hazard_unit only handles data hazards / forwarding).
    assign flush = branch_taken;

// =============================================================================
// 6.  EX/MEM PIPELINE REGISTER  (spec §5.3)
//
// Note: exmem_branch, exmem_jump, exmem_zero are NOT stored here.
//       Branch/jump decisions are fully resolved in EX; there is no need to
//       carry these flags forward to MEM. Removing them saves flip-flops.
// =============================================================================

    reg [31:0] exmem_pc_plus4;
    // exmem_alu_result declared forward above as wire; back with a reg + alias
    reg  [31:0] exmem_alu_result_r;
    assign exmem_alu_result = exmem_alu_result_r;

    reg [31:0] exmem_rs2_data;
    reg [4:0]  exmem_rd_addr;
    reg        exmem_reg_write;
    reg        exmem_mem_read;
    reg        exmem_mem_write;
    reg [1:0]  exmem_mem_to_reg;
    reg [2:0]  exmem_funct3;

    always @(posedge clk) begin
        if (rst) begin
            exmem_pc_plus4     <= 32'h0;
            exmem_alu_result_r <= 32'h0;
            exmem_rs2_data     <= 32'h0;
            exmem_rd_addr      <= 5'h0;
            exmem_reg_write    <= 1'b0;
            exmem_mem_read     <= 1'b0;
            exmem_mem_write    <= 1'b0;
            exmem_mem_to_reg   <= 2'b00;
            exmem_funct3       <= 3'h0;
        end else begin
            exmem_pc_plus4     <= idex_pc_plus4;
            exmem_alu_result_r <= alu_result_E;
            exmem_rs2_data     <= fwd_src_b_pre; // post-forwarding store data
            exmem_rd_addr      <= idex_rd_addr;
            exmem_reg_write    <= idex_reg_write;
            exmem_mem_read     <= idex_mem_read;
            exmem_mem_write    <= idex_mem_write;
            exmem_mem_to_reg   <= idex_mem_to_reg;
            exmem_funct3       <= idex_funct3;
        end
    end

// =============================================================================
// 7.  MEM STAGE  (spec §6.7)
// =============================================================================

    wire [31:0] mem_rdata_M;
    wire [31:0] mem_rdata_ext_M;
    wire        mem_misaligned;   // Asserted on misaligned load/store address

    data_mem DMEM (
        .clk        (clk),
        .addr       (exmem_alu_result),
        .wdata      (exmem_rs2_data),
        .mem_read   (exmem_mem_read),
        .mem_write  (exmem_mem_write),
        .funct3     (exmem_funct3),
        .rdata      (mem_rdata_M),
        .misaligned (mem_misaligned)
    );

    load_extend LEXT (
        .mem_rdata (mem_rdata_M),
        .funct3    (exmem_funct3),
        .ext_data  (mem_rdata_ext_M)
    );

// =============================================================================
// 8.  MEM/WB PIPELINE REGISTER  (spec §5.4)
// =============================================================================

    // These are wires declared forward in §3/§5 — back them with regs
    reg [31:0] memwb_alu_result_r;
    assign memwb_alu_result = memwb_alu_result_r;

    reg [31:0] memwb_mem_data_r;
    assign memwb_mem_data = memwb_mem_data_r;

    reg [31:0] memwb_pc_plus4_r;
    reg [4:0]  memwb_rd_addr_r;
    reg        memwb_reg_write_r;
    reg [1:0]  memwb_mem_to_reg_r;
    assign memwb_mem_to_reg = memwb_mem_to_reg_r;

    always @(posedge clk) begin
        if (rst) begin
            memwb_alu_result_r  <= 32'h0;
            memwb_mem_data_r    <= 32'h0;
            memwb_pc_plus4_r    <= 32'h0;
            memwb_rd_addr_r     <= 5'h0;
            memwb_reg_write_r   <= 1'b0;
            memwb_mem_to_reg_r  <= 2'b00;
        end else begin
            memwb_alu_result_r  <= exmem_alu_result;
            memwb_mem_data_r    <= mem_rdata_ext_M;
            memwb_pc_plus4_r    <= exmem_pc_plus4;
            memwb_rd_addr_r     <= exmem_rd_addr;
            memwb_reg_write_r   <= exmem_reg_write;
            memwb_mem_to_reg_r  <= exmem_mem_to_reg;
        end
    end

// =============================================================================
// 9.  WB STAGE — Write-Back Mux  (spec §7.2)
// =============================================================================

    // wb_wdata, wb_rd_addr, wb_reg_write declared in §3
    assign wb_rd_addr   = memwb_rd_addr_r;
    assign wb_reg_write = memwb_reg_write_r;

    assign wb_wdata = (memwb_mem_to_reg_r == 2'b00) ? memwb_alu_result_r :  // ALU result
                      (memwb_mem_to_reg_r == 2'b01) ? memwb_mem_data_r    :  // Load data
                      (memwb_mem_to_reg_r == 2'b10) ? memwb_pc_plus4_r    :  // JAL/JALR link
                                                      32'h0;                  // Reserved

// =============================================================================
// 10. HAZARD DETECTION + FORWARDING UNIT  (spec §6.8)
// =============================================================================

    hazard_unit HAZARD (
        .ifid_rs1_addr  (rs1_addr_D),       // ID stage instruction's rs1 (for stall)
        .ifid_rs2_addr  (rs2_addr_D),       // ID stage instruction's rs2 (for stall)
        .idex_rs1_addr  (idex_rs1_addr),    // EX stage instruction's rs1 (for forwarding)
        .idex_rs2_addr  (idex_rs2_addr),    // EX stage instruction's rs2 (for forwarding)
        .idex_rd_addr   (idex_rd_addr),
        .idex_mem_read  (idex_mem_read),
        .exmem_rd_addr  (exmem_rd_addr),
        .exmem_reg_write(exmem_reg_write),
        .memwb_rd_addr  (memwb_rd_addr_r),
        .memwb_reg_write(memwb_reg_write_r),
        .stall          (stall),
        .fwd_a_sel      (fwd_a_sel),
        .fwd_b_sel      (fwd_b_sel)
    );

// =============================================================================
// 11. SIMULATION ASSERTIONS (no effect on synthesis)
// =============================================================================

    // synthesis translate_off
    always @(posedge clk) begin
        if (mem_misaligned && (exmem_mem_read || exmem_mem_write))
            $display("[riscv_top] MISALIGNED ACCESS at PC in MEM stage, addr=0x%08X",
                      exmem_alu_result);
        if (trap_D)
            $display("[riscv_top] TRAP (ECALL/EBREAK) at PC=0x%08X", ifid_pc);
    end
    // synthesis translate_on

// =============================================================================
// 12. EXTERNAL DEBUG OUTPUTS
//
// These outputs do not change the processor's operation. They expose selected
// internal signals for simulation, waveform viewing, FPGA debug, or an ILA.
// Existing testbenches that connect only clk and rst remain compatible when
// using named port connections.
// =============================================================================

    // Fetch / execute observation
    assign debug_pc         = pcF;
    assign debug_instr      = instrF;
    assign debug_alu_result = alu_result_E;

    // A valid write-back event excludes writes to x0, because x0 is hardwired
    // to zero and the register file ignores writes targeting register zero.
    assign debug_wb_data  = wb_wdata;
    assign debug_wb_rd    = wb_rd_addr;
    assign debug_wb_valid = wb_reg_write && (wb_rd_addr != 5'd0);

    // Pipeline control observation
    assign debug_stall        = stall;
    assign debug_flush        = flush;
    assign debug_branch_taken = branch_taken;
    assign debug_halt         = halt;

    // Memory-stage observation
    assign debug_mem_read        = exmem_mem_read;
    assign debug_mem_write       = exmem_mem_write;
    assign debug_mem_addr        = exmem_alu_result;
    assign debug_mem_wdata       = exmem_rs2_data;
    assign debug_mem_rdata       = mem_rdata_ext_M;
    assign debug_mem_misaligned  = mem_misaligned;

endmodule

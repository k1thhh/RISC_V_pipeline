// ID/EX pipeline register — standalone module
// (riscv_top.v inlines this logic; this file is for unit use)
module id_ex_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,
    input  wire        stall,
    input  wire [31:0] i_pc, i_pc_plus4, i_rs1_data, i_rs2_data, i_imm,
    input  wire [4:0]  i_rs1_addr, i_rs2_addr, i_rd_addr,
    input  wire [3:0]  i_alu_op,
    input  wire        i_alu_src, i_reg_write, i_mem_read, i_mem_write,
    input  wire [1:0]  i_mem_to_reg,
    input  wire        i_branch, i_jump,
    input  wire [2:0]  i_funct3,
    output reg [31:0] o_pc, o_pc_plus4, o_rs1_data, o_rs2_data, o_imm,
    output reg [4:0]  o_rs1_addr, o_rs2_addr, o_rd_addr,
    output reg [3:0]  o_alu_op,
    output reg        o_alu_src, o_reg_write, o_mem_read, o_mem_write,
    output reg [1:0]  o_mem_to_reg,
    output reg        o_branch, o_jump,
    output reg [2:0]  o_funct3
);
    always @(posedge clk) begin
        if (rst || flush) begin
            o_pc<=0; o_pc_plus4<=0; o_rs1_data<=0; o_rs2_data<=0; o_imm<=0;
            o_rs1_addr<=0; o_rs2_addr<=0; o_rd_addr<=0; o_alu_op<=4'hF;
            o_alu_src<=0; o_reg_write<=0; o_mem_read<=0; o_mem_write<=0;
            o_mem_to_reg<=0; o_branch<=0; o_jump<=0; o_funct3<=0;
        end else if (!stall) begin
            o_pc<=i_pc; o_pc_plus4<=i_pc_plus4; o_rs1_data<=i_rs1_data;
            o_rs2_data<=i_rs2_data; o_imm<=i_imm;
            o_rs1_addr<=i_rs1_addr; o_rs2_addr<=i_rs2_addr; o_rd_addr<=i_rd_addr;
            o_alu_op<=i_alu_op; o_alu_src<=i_alu_src; o_reg_write<=i_reg_write;
            o_mem_read<=i_mem_read; o_mem_write<=i_mem_write; o_mem_to_reg<=i_mem_to_reg;
            o_branch<=i_branch; o_jump<=i_jump; o_funct3<=i_funct3;
        end
    end
endmodule

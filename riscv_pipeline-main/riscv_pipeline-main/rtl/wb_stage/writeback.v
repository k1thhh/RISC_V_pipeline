// Write-Back mux — standalone module
// (riscv_top.v inlines this as an assign; this file is for unit use)
module writeback (
    input  wire [31:0] alu_result,
    input  wire [31:0] mem_rdata,
    input  wire [31:0] pc_plus4,
    input  wire [1:0]  mem_to_reg,
    output wire [31:0] rd_wdata
);
    assign rd_wdata = (mem_to_reg == 2'b00) ? alu_result :
                      (mem_to_reg == 2'b01) ? mem_rdata  :
                      (mem_to_reg == 2'b10) ? pc_plus4   :
                                              32'h0;
endmodule

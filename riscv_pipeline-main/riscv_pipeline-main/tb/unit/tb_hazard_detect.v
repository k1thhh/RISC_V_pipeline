`timescale 1ns/1ps
// Tests hazard_unit forwarding and stall logic
module tb_hazard_detect;
    // ID stage sources (for load-use stall detection)
    reg [4:0]  ifid_rs1_addr, ifid_rs2_addr;
    // EX stage sources and destination
    reg [4:0]  idex_rs1_addr, idex_rs2_addr, idex_rd_addr;
    reg        idex_mem_read;
    reg [4:0]  exmem_rd_addr, memwb_rd_addr;
    reg        exmem_reg_write, memwb_reg_write;
    wire       stall;
    wire [1:0] fwd_a_sel, fwd_b_sel;

    // flush is driven by branch_taken in riscv_top, not by hazard_unit

    hazard_unit DUT(
        .ifid_rs1_addr (ifid_rs1_addr),
        .ifid_rs2_addr (ifid_rs2_addr),
        .idex_rs1_addr (idex_rs1_addr),
        .idex_rs2_addr (idex_rs2_addr),
        .idex_rd_addr  (idex_rd_addr),
        .idex_mem_read (idex_mem_read),
        .exmem_rd_addr (exmem_rd_addr),
        .exmem_reg_write(exmem_reg_write),
        .memwb_rd_addr (memwb_rd_addr),
        .memwb_reg_write(memwb_reg_write),
        .stall         (stall),
        .fwd_a_sel     (fwd_a_sel),
        .fwd_b_sel     (fwd_b_sel)
    );

    integer errors = 0;
    initial begin
        // No hazard baseline
        ifid_rs1_addr=7; ifid_rs2_addr=8;   // ID instruction uses x7,x8 — no match
        idex_rs1_addr=1; idex_rs2_addr=2; idex_rd_addr=3; idex_mem_read=0;
        exmem_rd_addr=5; exmem_reg_write=1;
        memwb_rd_addr=6; memwb_reg_write=1;
        #1;
        if (stall!==0||fwd_a_sel!==0||fwd_b_sel!==0)
            begin $display("FAIL no-hazard"); errors=errors+1; end
        else $display("PASS no hazard");

        // EX-EX forward A (EX instr rs1=1, EX/MEM rd=1)
        exmem_rd_addr=1; exmem_reg_write=1; #1;
        if (fwd_a_sel!==2'b01) begin $display("FAIL EX-EX fwd_a"); errors=errors+1; end
        else $display("PASS EX-EX fwd A");
        exmem_rd_addr=5;

        // MEM-EX forward B (EX instr rs2=2, MEM/WB rd=2)
        memwb_rd_addr=2; memwb_reg_write=1; #1;
        if (fwd_b_sel!==2'b10) begin $display("FAIL MEM-EX fwd_b"); errors=errors+1; end
        else $display("PASS MEM-EX fwd B");
        memwb_rd_addr=6;

        // Load-use stall: load in EX (idex_mem_read=1, idex_rd=1),
        // dependent instruction in ID uses rs1=1 (ifid_rs1_addr=1)
        idex_mem_read=1; idex_rd_addr=1; ifid_rs1_addr=1; #1;
        if (stall!==1) begin $display("FAIL load-use stall"); errors=errors+1; end
        else $display("PASS load-use stall");
        idex_mem_read=0; idex_rd_addr=3; ifid_rs1_addr=7;

        // No stall if load rd=x0 (x0 is hardwired zero, never a real dependency)
        idex_mem_read=1; idex_rd_addr=0; ifid_rs1_addr=0; #1;
        if (stall!==0) begin $display("FAIL x0 no stall"); errors=errors+1; end
        else $display("PASS x0 no stall");

        $display("\n%s — %0d error(s)", errors==0 ? "ALL PASS" : "FAILURES", errors);
        $finish;
    end
endmodule

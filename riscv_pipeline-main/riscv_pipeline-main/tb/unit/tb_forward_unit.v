`timescale 1ns/1ps
// Forward unit is part of hazard_unit — this testbench aliases it
module tb_forward_unit;
    // ifid_rs1/rs2 needed for load-use stall detection (not exercised here, tie to 0)
    reg [4:0]  ifid_rs1_addr, ifid_rs2_addr;
    reg [4:0]  rs1_addr, rs2_addr, idex_rd, exmem_rd, memwb_rd;
    reg        exmem_rw, memwb_rw;
    wire [1:0] fwd_a, fwd_b;
    wire       stall_unused;

    hazard_unit DUT(
        .ifid_rs1_addr  (ifid_rs1_addr),
        .ifid_rs2_addr  (ifid_rs2_addr),
        .idex_rs1_addr  (rs1_addr),
        .idex_rs2_addr  (rs2_addr),
        .idex_rd_addr   (idex_rd),
        .idex_mem_read  (1'b0),
        .exmem_rd_addr  (exmem_rd),
        .exmem_reg_write(exmem_rw),
        .memwb_rd_addr  (memwb_rd),
        .memwb_reg_write(memwb_rw),
        .stall          (stall_unused),
        .fwd_a_sel      (fwd_a),
        .fwd_b_sel      (fwd_b)
    );

    integer errors = 0;
    initial begin
        ifid_rs1_addr=0; ifid_rs2_addr=0; // tie unused stall inputs to 0
        idex_rd=3; rs1_addr=1; rs2_addr=2; memwb_rd=9; memwb_rw=0;

        // EX priority over MEM for A
        exmem_rd=1; exmem_rw=1; memwb_rd=1; memwb_rw=1; #1;
        if (fwd_a!==2'b01) begin $display("FAIL EX>MEM priority A"); errors=errors+1; end
        else $display("PASS EX>MEM priority A");

        // MEM forward for B when no EX conflict
        exmem_rd=9; exmem_rw=1; memwb_rd=2; memwb_rw=1; #1;
        if (fwd_b!==2'b10) begin $display("FAIL MEM fwd B"); errors=errors+1; end
        else $display("PASS MEM fwd B");

        // No forward when reg_write=0
        exmem_rd=1; exmem_rw=0; memwb_rd=2; memwb_rw=0; #1;
        if (fwd_a!==2'b00||fwd_b!==2'b00)
            begin $display("FAIL no-rw no fwd"); errors=errors+1; end
        else $display("PASS no-rw no fwd");

        $display("\n%s — %0d error(s)", errors==0 ? "ALL PASS" : "FAILURES", errors);
        $finish;
    end
endmodule

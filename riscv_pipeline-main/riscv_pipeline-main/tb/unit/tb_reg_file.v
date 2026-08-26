`timescale 1ns/1ps
module tb_reg_file;
    reg        clk = 0, rst = 1;
    reg  [4:0] rs1_addr, rs2_addr, rd_addr;
    reg  [31:0] wdata;
    reg         reg_write;
    wire [31:0] rdata1, rdata2;

    reg_file DUT(.clk(clk),.rst(rst),.rs1_addr(rs1_addr),.rs2_addr(rs2_addr),
                 .rdata1(rdata1),.rdata2(rdata2),.rd_addr(rd_addr),.wdata(wdata),.reg_write(reg_write));

    always #5 clk = ~clk;
    integer errors = 0;

    initial begin
        // Reset
        rst=1; reg_write=0; rd_addr=0; wdata=0; rs1_addr=0; rs2_addr=0;
        @(posedge clk); @(negedge clk);
        rst = 0;

        // x0 always 0
        rs1_addr = 0; #1;
        if (rdata1 !== 0) begin $display("FAIL x0!=0"); errors=errors+1; end
        else $display("PASS x0=0");

        // Write x5 = 42
        rd_addr=5; wdata=42; reg_write=1;
        @(posedge clk); @(negedge clk);
        reg_write=0;
        rs1_addr=5; #1;
        if (rdata1 !== 42) begin $display("FAIL x5 got %0d",rdata1); errors=errors+1; end
        else $display("PASS x5=42");

        // Write-then-read forwarding: x5=99 before clock
        rd_addr=5; wdata=99; reg_write=1;
        rs1_addr=5; #1;
        if (rdata1 !== 99) begin $display("FAIL fwd got %0d exp 99",rdata1); errors=errors+1; end
        else $display("PASS write-fwd x5=99");
        @(posedge clk); @(negedge clk);
        reg_write=0;

        // Two-port simultaneous read
        rd_addr=6; wdata=7; reg_write=1;
        @(posedge clk); @(negedge clk);
        reg_write=0;
        rs1_addr=5; rs2_addr=6; #1;
        if (rdata1!==99||rdata2!==7) begin
            $display("FAIL 2-port: x5=%0d x6=%0d",rdata1,rdata2); errors=errors+1;
        end else $display("PASS 2-port read");

        $display("\n%s — %0d error(s)", errors==0 ? "ALL PASS" : "FAILURES", errors);
        $finish;
    end
endmodule

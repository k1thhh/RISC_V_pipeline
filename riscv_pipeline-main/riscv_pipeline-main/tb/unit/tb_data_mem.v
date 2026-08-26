`timescale 1ns/1ps
module tb_data_mem;
    reg        clk = 0, mem_read, mem_write;
    reg  [31:0] addr, wdata;
    reg  [2:0]  funct3;
    wire [31:0] rdata;
    wire        misaligned;

    data_mem DUT(.clk(clk),.addr(addr),.wdata(wdata),.mem_read(mem_read),
                 .mem_write(mem_write),.funct3(funct3),.rdata(rdata),
                 .misaligned(misaligned));
    always #5 clk = ~clk;

    integer errors = 0;
    task check;
        input [31:0] got, exp;
        input [127:0] label;
        begin
            if (got!==exp) begin $display("FAIL %s: got 0x%08X exp 0x%08X",label,got,exp); errors=errors+1; end
            else $display("PASS %s",label);
        end
    endtask

    initial begin
        mem_write=0; mem_read=0; addr=0; wdata=0; funct3=3'b010;

        // SW then LW
        addr=32'h10; wdata=32'hDEADBEEF; funct3=3'b010; mem_write=1;
        @(posedge clk); @(negedge clk); mem_write=0;
        mem_read=1; #1;
        check(rdata,32'hDEADBEEF,"SW/LW word  ");
        mem_read=0;

        // SB then LB (signed)
        addr=32'h20; wdata=32'hFF; funct3=3'b000; mem_write=1;
        @(posedge clk); @(negedge clk); mem_write=0;
        mem_read=1; #1;
        check(rdata[7:0],8'hFF,"SB byte     ");
        mem_read=0;

        // SH then LH
        addr=32'h30; wdata=32'hABCD; funct3=3'b001; mem_write=1;
        @(posedge clk); @(negedge clk); mem_write=0;
        funct3=3'b001; mem_read=1; #1;
        check(rdata[15:0],16'hABCD,"SH/LH half  ");
        mem_read=0;

        $display("\n%s — %0d error(s)", errors==0 ? "ALL PASS" : "FAILURES", errors);
        $finish;
    end
endmodule

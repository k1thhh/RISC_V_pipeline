`timescale 1ns/1ps
module tb_imm_gen;
    reg  [31:0] instr;
    wire [31:0] imm;
    imm_gen DUT(.instr(instr),.imm(imm));

    integer errors = 0;
    task check;
        input [31:0] got, exp;
        input [127:0] label;
        begin
            if (got !== exp) begin
                $display("FAIL %s: got 0x%08X exp 0x%08X", label, got, exp);
                errors = errors + 1;
            end else $display("PASS %s", label);
        end
    endtask

    initial begin
        // addi x1, x0, 5  (I-type, imm=5)  0x00500093
        instr = 32'h00500093; #1;
        check(imm, 32'd5, "I-type imm=5    ");

        // addi x1, x0, -1 (I-type, imm=-1) 0xFFF00093
        instr = 32'hFFF00093; #1;
        check(imm, 32'hFFFFFFFF, "I-type imm=-1   ");

        // sw x1, 8(x2)  S-type, imm=8
        // imm[11:5]=0000000, imm[4:0]=01000  => 0x00112423
        instr = 32'h00112423; #1;
        check(imm, 32'd8, "S-type imm=8    ");

        // lui x1, 1  (U-type, imm=0x1000)  0x00001037
        instr = 32'h00001037; #1;
        check(imm, 32'h00001000, "U-type imm=0x1000");

        // jal x0, 8  (J-type, offset=8)
        // offset=8: imm[20]=0,imm[10:1]=0000000100,imm[11]=0,imm[19:12]=00000000
        // 0x0080006F
        instr = 32'h0080006F; #1;
        check(imm, 32'd8, "J-type imm=8    ");

        // beq x0,x0, 4  (B-type, offset=4)  0x00000263
        instr = 32'h00000263; #1;
        check(imm, 32'd4, "B-type imm=4    ");

        $display("\n%s — %0d error(s)", errors==0 ? "ALL PASS" : "FAILURES", errors);
        $finish;
    end
endmodule

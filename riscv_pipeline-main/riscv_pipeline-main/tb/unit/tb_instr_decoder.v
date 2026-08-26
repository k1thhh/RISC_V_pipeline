`timescale 1ns/1ps
module tb_instr_decoder;
    reg  [31:0] instr;
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [4:0]  rs1, rs2, rd;
    instr_decoder DUT(.instr(instr),.opcode(opcode),.funct3(funct3),.funct7(funct7),
                      .rs1(rs1),.rs2(rs2),.rd(rd));

    integer errors = 0;
    // add x3, x1, x2 = 0x002081B3
    initial begin
        instr = 32'h002081B3; #1;
        if (opcode!==7'b0110011) begin $display("FAIL opcode"); errors=errors+1; end
        else $display("PASS opcode=R-type");
        if (rd!==5'd3)   begin $display("FAIL rd=%0d exp 3",rd); errors=errors+1; end
        else $display("PASS rd=3");
        if (rs1!==5'd1)  begin $display("FAIL rs1=%0d exp 1",rs1); errors=errors+1; end
        else $display("PASS rs1=1");
        if (rs2!==5'd2)  begin $display("FAIL rs2=%0d exp 2",rs2); errors=errors+1; end
        else $display("PASS rs2=2");
        if (funct3!==3'b000) begin $display("FAIL funct3"); errors=errors+1; end
        else $display("PASS funct3=0");
        if (funct7!==7'b0000000) begin $display("FAIL funct7"); errors=errors+1; end
        else $display("PASS funct7=0");
        $display("\n%s — %0d error(s)", errors==0 ? "ALL PASS" : "FAILURES", errors);
        $finish;
    end
endmodule

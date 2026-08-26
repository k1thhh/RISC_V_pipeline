`timescale 1ns/1ps
module tb_alu;
    reg  [31:0] operand_a, operand_b;
    reg  [3:0]  ALUControl;
    wire [31:0] result;
    wire        Zero, Negative, Carry, Overflow;

    alu DUT(.operand_a(operand_a),.operand_b(operand_b),.ALUControl(ALUControl),
            .result(result),.Zero(Zero),.Negative(Negative),.Carry(Carry),.Overflow(Overflow));

    integer errors = 0;
    task check;
        input [31:0] got, exp;
        input [63:0] label;
        begin
            if (got !== exp) begin
                $display("FAIL %s: got 0x%08X exp 0x%08X", label, got, exp);
                errors = errors + 1;
            end else $display("PASS %s", label);
        end
    endtask

    initial begin
        // ADD
        ALUControl=4'b0000; operand_a=32'd10; operand_b=32'd5; #1;
        check(result,32'd15,"ADD  10+5  ");

        // SUB
        ALUControl=4'b0001; operand_a=32'd10; operand_b=32'd5; #1;
        check(result,32'd5,"SUB  10-5  ");

        // SUB zero flag
        ALUControl=4'b0001; operand_a=32'd7; operand_b=32'd7; #1;
        if (Zero !== 1) begin $display("FAIL SUB zero flag"); errors=errors+1; end
        else $display("PASS SUB zero flag");

        // AND
        ALUControl=4'b0010; operand_a=32'hFF00; operand_b=32'h0F0F; #1;
        check(result,32'h0F00,"AND        ");

        // OR
        ALUControl=4'b0011; operand_a=32'hFF00; operand_b=32'h0F0F; #1;
        check(result,32'hFF0F,"OR         ");

        // XOR
        ALUControl=4'b0100; operand_a=32'hFFFF; operand_b=32'h0F0F; #1;
        check(result,32'hF0F0,"XOR        ");

        // SLL
        ALUControl=4'b0101; operand_a=32'h1; operand_b=32'd3; #1;
        check(result,32'h8,"SLL 1<<3   ");

        // SRL
        ALUControl=4'b0110; operand_a=32'h80000000; operand_b=32'd1; #1;
        check(result,32'h40000000,"SRL        ");

        // SRA (arithmetic, preserves sign)
        ALUControl=4'b0111; operand_a=32'h80000000; operand_b=32'd1; #1;
        check(result,32'hC0000000,"SRA        ");

        // SLT signed
        ALUControl=4'b1000; operand_a=32'hFFFFFFFF; operand_b=32'h1; #1;
        check(result,32'h1,"SLT -1<1   ");

        // SLTU unsigned
        ALUControl=4'b1001; operand_a=32'h1; operand_b=32'hFFFFFFFF; #1;
        check(result,32'h1,"SLTU 1<MAX ");

        // PASS_B (LUI)
        ALUControl=4'b1010; operand_a=32'hDEAD; operand_b=32'hBEEF_0000; #1;
        check(result,32'hBEEF_0000,"PASS_B     ");

        $display("\n%s — %0d error(s)", errors==0 ? "ALL PASS" : "FAILURES", errors);
        $finish;
    end
endmodule

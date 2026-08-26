// ============================================================
// Testbench   : tb_branch_unit
// File        : tb/unit/tb_branch_unit.v
// Tests       : branch_unit.v
// ============================================================

module tb_branch_unit;

    // inputs to branch_unit (we control these)
    reg [31:0] rs1_data;
    reg [31:0] rs2_data;
    reg [31:0] pc;
    reg [31:0] pc_plus4;
    reg [31:0] imm;
    reg [2:0]  funct3;
    reg        branch;
    reg        jump;
    reg        alu_src;

    // outputs from branch_unit (we just observe these)
    wire        branch_taken;
    wire [31:0] branch_target;

    // connect testbench to your module
    branch_unit uut (
        .rs1_data     (rs1_data),
        .rs2_data     (rs2_data),
        .pc           (pc),
        .pc_plus4     (pc_plus4),
        .imm          (imm),
        .funct3       (funct3),
        .branch       (branch),
        .jump         (jump),
        .alu_src      (alu_src),
        .branch_taken (branch_taken),
        .branch_target(branch_target)
    );

    initial begin
        $display("=============================");
        $display("   Branch Unit Test Cases    ");
        $display("=============================");

        branch=0; jump=0; alu_src=0;
        funct3=0; 
        pc=0; pc_plus4=0; imm=0; rs1_data=0; rs2_data=0;
        #10;

        // TEST 1: BEQ taken
        branch=1; jump=0; alu_src=0;
        funct3=3'b000;
        rs1_data=32'd10; rs2_data=32'd10; // equal
        pc=32'h100;
        imm=32'h8;
        #10;
        $display("TEST 1 BEQ taken   : branch_taken=%b (want 1), branch_target=%h (want 108)", branch_taken, branch_target);

        // TEST 2: BEQ no take
        rs2_data=32'd11; // not equal
        #10;
        $display("TEST 2 BEQ no take : branch_taken=%b (want 0)", branch_taken);

        // TEST 3: BNE taken
        funct3=3'b001;
        // rs1=10, rs2=11 -> not equal
        #10;
        $display("TEST 3 BNE taken   : branch_taken=%b (want 1)", branch_taken);

        // TEST 4: BLT taken
        funct3=3'b100;
        rs1_data=-32'd5; rs2_data=32'd2; // -5 < 2
        #10;
        $display("TEST 4 BLT taken   : branch_taken=%b (want 1)", branch_taken);

        // TEST 5: BLT no take
        rs1_data=32'd5; rs2_data=32'd2; // 5 is not < 2
        #10;
        $display("TEST 5 BLT no take : branch_taken=%b (want 0)", branch_taken);

        // TEST 6: JAL
        branch=0; jump=1; alu_src=0; // JAL has alu_src=0
        pc=32'h200;
        imm=32'h40;
        #10;
        $display("TEST 6 JAL         : branch_taken=%b (want 1), branch_target=%h (want 240)", branch_taken, branch_target);

        // TEST 7: JALR
        jump=1; alu_src=1; // JALR has alu_src=1
        rs1_data=32'hABC;
        imm=32'h4;
        #10;
        $display("TEST 7 JALR        : branch_taken=%b (want 1), branch_target=%h (want ac0)", branch_taken, branch_target);

        // TEST 8: JALR align
        rs1_data=32'hABC;
        imm=32'h3;
        #10;
        $display("TEST 8 JALR align  : branch_target=%h (want abe)", branch_target);

        // TEST 9: HALT check
        branch=0; jump=0; alu_src=0;
        funct3=3'b000; 
        #10;
        $display("TEST 9 HALT check  : branch_taken=%b (want 0)", branch_taken);

        $display("=============================");
        $display("        Tests Done!          ");
        $display("=============================");
        $finish;
    end

endmodule

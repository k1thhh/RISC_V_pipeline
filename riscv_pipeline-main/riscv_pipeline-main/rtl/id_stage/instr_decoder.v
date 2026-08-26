module instr_decoder (
    input wire [31:0] instr,
    output wire [6:0] opcode,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output wire [4:0] rs1, 
    output wire [4:0] rs2,
    output wire [4:0] rd
);
    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    // Decode instruction format to mask unused registers.
    // This prevents false data hazards in the pipeline.
    wire is_r_type = (opcode == 7'b0110011);
    wire is_i_type = (opcode == 7'b0010011) || (opcode == 7'b0000011) || (opcode == 7'b1100111) || (opcode == 7'b1110011) || (opcode == 7'b0001111);
    wire is_s_type = (opcode == 7'b0100011);
    wire is_b_type = (opcode == 7'b1100011);
    wire is_u_type = (opcode == 7'b0110111) || (opcode == 7'b0010111);
    wire is_j_type = (opcode == 7'b1101111);

    wire uses_rs1 = is_r_type | is_i_type | is_s_type | is_b_type;
    wire uses_rs2 = is_r_type | is_s_type | is_b_type;
    wire uses_rd  = is_r_type | is_i_type | is_u_type | is_j_type;

    assign rs1 = uses_rs1 ? instr[19:15] : 5'b00000;
    assign rs2 = uses_rs2 ? instr[24:20] : 5'b00000;
    assign rd  = uses_rd  ? instr[11:7]  : 5'b00000;

endmodule

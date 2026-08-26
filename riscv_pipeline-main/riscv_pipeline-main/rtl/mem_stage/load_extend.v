// rtl/mem_stage/load_extend.v
// "The Load Sign‑Extension / Zero‑Extension Unit"
// =============================================================================
//
// When the CPU executes a load instruction, the data memory always returns
// a 32‑bit value that has been **zero‑extended** to the full width.
// For example, a byte load from address 0x3 gives us a word where the lowest
// 8 bits are the real data, and the upper 24 bits are zero.
//
// That’s perfect for unsigned loads (LBU, LHU), but for **signed** loads
// (LB, LH) we must copy the sign bit of the loaded data into all the upper
// bits.  This module does exactly that: it looks at funct3 to decide which
// kind of extension to apply and outputs the final, correctly extended value.
//
// The rules are simple:
//   - funct3 = 3'b000  → LB  → sign‑extend byte   (bit 7 → bits 31..8)
//   - funct3 = 3'b100  → LBU → zero‑extend byte   (leave upper bits zero)
//   - funct3 = 3'b001  → LH  → sign‑extend half   (bit 15 → bits 31..16)
//   - funct3 = 3'b101  → LHU → zero‑extend half   (leave upper bits zero)
//   - funct3 = 3'b010  → LW  → no change (word)
//
// This matches exactly the load instructions in the RV32I instruction set.
// =============================================================================

module load_extend (
    input  wire [31:0] mem_rdata,   // Raw data straight out of data_mem
    input  wire [2:0]  funct3,      // funct3 field tells us load type
    output reg  [31:0] ext_data     // The correctly extended result
);

    // We use a combinational always block so that ext_data updates immediately
    // whenever the inputs change – no extra clock cycle wasted.
    always @(*) begin
        case (funct3)
            // ---- Byte signed (LB) ----
            3'b000: begin
                // The real data is in bits 7..0.  We need to copy bit 7
                // into all the upper bits if the byte was negative.
                // In Verilog, this is easiest with $signed and a cast, but
                // we can do it manually: fill bits 31..8 with mem_rdata[7].
                ext_data = {{24{mem_rdata[7]}}, mem_rdata[7:0]};
            end

            // ---- Halfword signed (LH) ----
            3'b001: begin
                // Sign bit is now bit 15.  Replicate it into bits 31..16.
                ext_data = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
            end

            // ---- Byte unsigned (LBU) ----
            3'b100: begin
                // The upper bits are already zero because data_mem zero‑extends.
                // But to be explicit (and safe if data_mem ever changes), we
                // force the upper bits to zero.
                ext_data = {24'h0, mem_rdata[7:0]};
            end

            // ---- Halfword unsigned (LHU) ----
            3'b101: begin
                // Force upper 16 bits to zero.
                ext_data = {16'h0, mem_rdata[15:0]};
            end

            // ---- Word (LW) ----
            3'b010: begin
                // Nothing to extend – just pass the whole word through.
                ext_data = mem_rdata;
            end

            // ---- Default / unexpected funct3 ----
            default: begin
                // If we ever get a strange funct3 value,it just passes the data
                // through unchanged.  This won't happen in a correct CPU,
                // but it stops the synthesizer from complaining about latches.
                ext_data = mem_rdata;
            end
        endcase
    end

endmodule

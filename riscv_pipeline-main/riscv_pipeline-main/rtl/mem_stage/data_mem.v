// =============================================================================
// data_mem.v — Parameterised Byte-Addressable Data Memory
// =============================================================================
//
// This is the data memory (RAM) of the processor. It handles all load and
// store instructions: LB, LH, LW, LBU, LHU, SB, SH, SW.
//
// MEMORY SIZE
//   The number of 32-bit words is controlled by the parameter DEPTH.
//   Default = 512 words (2048 bytes = 2 KB). To change the size, override
//   DEPTH when instantiating — no internal code changes are needed.
//   Address width is calculated automatically from DEPTH using $clog2.
//
//   Example: data_mem #(.DEPTH(1024)) DMEM (...);  // 4 KB memory
//
// READ / WRITE BEHAVIOUR
//   Read  – combinational, gated on mem_read. The data appears immediately
//           when mem_read is asserted. When mem_read=0, rdata is 0.
//   Write – synchronous. Data is stored only on the rising edge when
//           mem_write is high.
//
// ACCESS SIZES (funct3[1:0])
//   00 → byte      01 → halfword      10 → word
//   funct3[2] distinguishes signed/unsigned loads (handled by load_extend).
//
// MISALIGNED ACCESS DETECTION
//   The misaligned output is asserted for:
//     - halfword (funct3[1:0]==01) at an odd address (addr[0] != 0)
//     - word     (funct3[1:0]==10) at a non-4-byte-aligned address (addr[1:0] != 0)
//   Hardware does NOT abort the access on misalignment; use misaligned for
//   an assertion or trap handler in the connected logic.
//
// BYTE ORDER
//   Little-endian (RISC-V standard). Byte 0 is the least significant byte.
// =============================================================================

module data_mem #(
    parameter DEPTH = 512                     // words in memory (power-of-2 recommended)
) (
    input  wire        clk,                   // Global clock
    input  wire [31:0] addr,                  // Byte address (from ALU result)
    input  wire [31:0] wdata,                 // Data to store (from rs2 after forwarding)
    input  wire        mem_read,              // Load enable (1 = read is active)
    input  wire        mem_write,             // Store enable (1 = write is active)
    input  wire [2:0]  funct3,                // funct3 field (size + signedness)
    output wire [31:0] rdata,                 // Read data (combinational, gated on mem_read)
    output wire        misaligned             // Asserted when access is misaligned
);

    localparam ADDR_BITS = $clog2(DEPTH);

    // ----- The actual storage --------------------------------------------------
    reg [31:0] mem [0:DEPTH-1];

    // ----- Address decoding ----------------------------------------------------
    wire [ADDR_BITS-1:0] word_addr   = addr[ADDR_BITS+1:2];
    wire [1:0]           byte_offset = addr[1:0];

    // ==========================================================================
    // MISALIGNED DETECTION
    //   halfword must be at an even address; word must be 4-byte aligned.
    //   byte accesses are always aligned by definition.
    // ==========================================================================
    assign misaligned = (funct3[1:0] == 2'b01 && addr[0]   != 1'b0) ||   // halfword, odd addr
                        (funct3[1:0] == 2'b10 && addr[1:0] != 2'b00);    // word, not 4-aligned

    // Simulation-time misalignment assertion (no effect on synthesis)
    // synthesis translate_off
    always @(posedge clk) begin
        if ((mem_read || mem_write) && misaligned)
            $display("[data_mem] WARNING: misaligned access at addr=0x%08X funct3=%b",
                      addr, funct3);
    end
    // synthesis translate_on

    // ==========================================================================
    // READ PATH (combinational, gated on mem_read)
    //   When mem_read=0, rdata is forced to 0 to avoid propagating stale
    //   memory values into the MEM/WB register on non-load cycles.
    // ==========================================================================
    reg [31:0] rd_pre;

    always @(*) begin
        rd_pre = 32'h0;
        if (mem_read) begin
            case (funct3[1:0])                    // only care about access size
                2'b00: begin                      // Byte load
                    rd_pre[7:0] = mem[word_addr][byte_offset*8 +: 8];
                end
                2'b01: begin                      // Halfword load
                    if (byte_offset[1] == 1'b0)
                        rd_pre[15:0] = mem[word_addr][15:0];
                    else
                        rd_pre[15:0] = mem[word_addr][31:16];
                end
                2'b10: begin                      // Word load
                    rd_pre = mem[word_addr];
                end
                default: rd_pre = 32'h0;
            endcase
        end
    end

    assign rdata = rd_pre;

    // ==========================================================================
    // WRITE PATH (synchronous)
    //   Write only the targeted byte lanes; other bytes in the same word
    //   are preserved.
    // ==========================================================================
    always @(posedge clk) begin
        if (mem_write) begin
            case (funct3[1:0])
                2'b00: // Store byte
                    mem[word_addr][byte_offset*8 +: 8] <= wdata[7:0];
                2'b01: // Store halfword
                    if (byte_offset[1] == 1'b0)
                        mem[word_addr][15:0]  <= wdata[15:0];
                    else
                        mem[word_addr][31:16] <= wdata[15:0];
                2'b10: // Store word
                    mem[word_addr] <= wdata;
                // default: no store (safety)
            endcase
        end
    end

endmodule

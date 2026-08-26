// =============================================================================
// reg_file.v — 32x32-bit Register File
// Stage: ID (reads combinational, write synchronous)
//
// Properties:
//   - 32 registers, each 32 bits wide
//   - x0 is hardwired to 0 (reads always return 0, writes are ignored)
//   - Two asynchronous read ports (rs1, rs2)
//   - One synchronous write port (rd), written on posedge clk
//   - Write-then-read forwarding: if rd == rs1 (or rs2) in the same cycle,
//     the new wdata is immediately forwarded to the read output (no stale read)
//
// Reset behaviour:
//   The reset input is intentionally not used to clear the register array.
//   Resetting 32 × 32 flip-flops costs significant area in silicon and is
//   unnecessary because:
//     (a) x0 is hardwired to 0 in the read path regardless of stored value.
//     (b) All other registers are undefined at power-on in real silicon anyway;
//         correct programs initialise them before use.
//   The rst input is kept in the port list for interface compatibility.
// =============================================================================

module reg_file (
    input  wire        clk,
    input  wire        rst,        // Kept for interface compatibility; see note above
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] wdata,
    input  wire        reg_write
);
    reg [31:0] regs [0:31];

    // Synchronous write (x0 write is suppressed)
    always @(posedge clk) begin
        if (reg_write && rd_addr != 5'h0)
            regs[rd_addr] <= wdata;
    end

    // Asynchronous read with x0 hardwiring and write-then-read forwarding
    assign rdata1 = (rs1_addr == 5'h0)                      ? 32'h0  :
                    (reg_write && rd_addr == rs1_addr)       ? wdata  :
                    regs[rs1_addr];

    assign rdata2 = (rs2_addr == 5'h0)                      ? 32'h0  :
                    (reg_write && rd_addr == rs2_addr)       ? wdata  :
                    regs[rs2_addr];

endmodule

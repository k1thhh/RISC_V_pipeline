// =============================================================================
// instr_mem.v — Instruction Memory (ROM, simulation model)
//
// SIMULATION ONLY: $readmemh is used to initialise the ROM from a hex file.
// For synthesis, replace this module with a vendor BRAM/ROM primitive or an
// IP block — do not synthesise the $readmemh path.
//
// The HEX_FILE parameter must be set to an absolute path (or a path relative
// to the simulator's working directory) at instantiation time.
//
// Example override:
//   instr_mem #(.DEPTH(256), .HEX_FILE("/path/to/program.hex")) IMEM (...);
//
// Read behaviour: fully combinational (async ROM). The instruction appears on
// the output the same cycle the PC is applied.
// =============================================================================

module instr_mem #(
    parameter integer DEPTH    = 256,                          // words (default 1 KB)
    parameter         HEX_FILE = "programs/hex/fibonacci.hex"  // override at instantiation
) (
    input  wire [31:0] pc,    // Byte-addressed PC
    output wire [31:0] instr  // Instruction word at that address
);

    localparam ADDR_BITS = $clog2(DEPTH);

    reg [31:0] memory_array [0:DEPTH-1];

    // Simulation initialisation — not synthesisable
    // synthesis translate_off
    initial $readmemh(HEX_FILE, memory_array);
    // synthesis translate_on

    // Word-addressed read: ignore byte offset (bits [1:0])
    assign instr = memory_array[pc[ADDR_BITS+1:2]];

endmodule

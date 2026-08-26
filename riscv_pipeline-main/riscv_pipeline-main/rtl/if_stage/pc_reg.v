module pc_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,       // Enable signal (from hazard unit)
    input  wire [31:0] pc_next,  // The address we want to go to next
    output reg  [31:0] pc        // The current address
);

    // This block triggers on the rising edge of the clock
    always @(posedge clk) begin
        if (rst) begin
            // Synchronous reset: send PC to starting address
            pc <= 32'h00000000;
        end 
        else if (en) begin
            // If enabled (not stalled), update PC to the next address
            pc <= pc_next;
        end
        // If en is 0, the 'pc' keeps its current value (stalling)
    end

endmodule

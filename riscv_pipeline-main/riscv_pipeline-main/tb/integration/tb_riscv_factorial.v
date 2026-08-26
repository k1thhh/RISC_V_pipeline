`timescale 1ns/1ps

module tb_riscv_factorial;

    // Clock period T = 2 * CLK_HALF = 10 ns
    parameter CLK_HALF = 5;

    // Delay formula: C = (N_dynamic + 4) * 2
    // factorial dynamic instruction count N ~ 129
    // (7 fact_loop iters + 28 mul_loop iters with nested calls + JAL/branch flush overhead)
    // C = (129 + 4) * 2 = 266 cycles  →  total delay = 266 * 10ns = 2660 ns
    parameter MAX_CYCLES = 266;

    reg clk = 0;
    reg rst = 1;

    riscv_top DUT (
        .clk (clk),
        .rst (rst)
    );
    defparam DUT.IMEM.HEX_FILE = "programs/hex/factorial.hex";

    always #CLK_HALF clk = ~clk;

    integer cycle  = 0;
    integer errors = 0;

    initial begin
        rst = 1;
        repeat(2) @(posedge clk);
        @(negedge clk);
        rst = 0;
    end

    `ifdef DUMP_VCD
    initial begin
        $dumpfile("dump_fact.vcd");
        $dumpvars(0, tb_riscv_factorial);
    end
    `endif

    // Cycle counter — watchdog fires 20 cycles after MAX_CYCLES as a backstop only
    always @(posedge clk) begin
        if (!rst) begin
            cycle = cycle + 1;
            if (cycle >= MAX_CYCLES + 20) begin
                $display("WATCHDOG: simulation exceeded %0d cycles", MAX_CYCLES + 20);
                $finish;
            end
        end
    end

    // Wait MAX_CYCLES then check — hardware halt has frozen the CPU by now
    initial begin
        @(negedge rst);
        repeat(MAX_CYCLES) @(posedge clk);

        $display("\n--- Factorial result check (7! at mem word 4) ---");
        begin : check
            integer got;
            got = DUT.DMEM.mem[4];
            if (got !== 5040) begin
                $display("  FAIL 7! = %0d, expected 5040", got);
                errors = errors + 1;
            end else begin
                $display("  PASS 7! = %0d", got);
            end
        end

        if (errors == 0)
            $display("\nALL PASS");
        else
            $display("\n%0d FAILURES", errors);

        $finish;
    end

endmodule

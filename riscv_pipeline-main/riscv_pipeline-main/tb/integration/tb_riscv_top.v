`timescale 1ns/1ps

module tb_riscv_top;

    // Clock period T = 2 * CLK_HALF = 10 ns
    parameter CLK_HALF = 5;

    // Delay formula: C = (N_dynamic + 4) * 2
    // fibonacci dynamic instruction count N ~ 77 (8 preamble + 8 loop iters * 8 instr + 1 final beq + 3 nop + 1 halt)
    // C = (77 + 4) * 2 = 162 cycles  →  total delay = 162 * 10ns = 1620 ns
    parameter MAX_CYCLES = 162;

    reg clk = 0;
    reg rst = 1;

    riscv_top DUT (
        .clk (clk),
        .rst (rst)
    );
    defparam DUT.IMEM.HEX_FILE = "programs/hex/fibonacci.hex";

    always #CLK_HALF clk = ~clk;

    integer cycle  = 0;
    integer errors = 0;

    // Hold reset for 2 cycles
    initial begin
        rst = 1;
        repeat(2) @(posedge clk);
        @(negedge clk);
        rst = 0;
    end

    `ifdef DUMP_VCD
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_riscv_top);
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

        $display("\n--- Fibonacci result check ---");
        begin : check
            integer i;
            integer got, exp;
            integer fibs [0:9];
            fibs[0] = 0;  fibs[1] = 1;  fibs[2] = 1;  fibs[3] = 2;
            fibs[4] = 3;  fibs[5] = 5;  fibs[6] = 8;  fibs[7] = 13;
            fibs[8] = 21; fibs[9] = 34;

            for (i = 0; i < 10; i = i + 1) begin
                got = $signed(DUT.DMEM.mem[64 + i]);
                exp = fibs[i];
                if (got !== exp) begin
                    $display("  FAIL fib[%0d]: got %0d, expected %0d", i, got, exp);
                    errors = errors + 1;
                end else begin
                    $display("  PASS fib[%0d] = %0d", i, got);
                end
            end
        end

        if (errors == 0)
            $display("\nALL PASS");
        else
            $display("\n%0d FAILURES", errors);

        $finish;
    end

endmodule

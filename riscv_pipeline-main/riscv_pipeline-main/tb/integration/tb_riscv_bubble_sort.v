`timescale 1ns/1ps

module tb_riscv_bubble_sort;

    // Clock period T = 2 * CLK_HALF = 10 ns
    parameter CLK_HALF = 5;

    // Delay formula: C = (N_dynamic + 4) * 2
    // bubble_sort dynamic instruction count N ~ 370
    // (setup ~18 + 28 comparisons * ~11 instr/comparison + outer loop overhead ~35 + drain ~7)
    // C = (370 + 4) * 2 = 748 cycles  →  total delay = 748 * 10ns = 7480 ns
    parameter MAX_CYCLES = 748;

    reg clk = 0;
    reg rst = 1;

    riscv_top DUT (
        .clk (clk),
        .rst (rst)
    );
    defparam DUT.IMEM.HEX_FILE = "programs/hex/bubble_sort.hex";

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
        $dumpfile("dump_sort.vcd");
        $dumpvars(0, tb_riscv_bubble_sort);
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

        $display("\n--- Bubble sort result check (8 elements) ---");
        begin : check
            integer i;
            integer got, exp;
            integer sorted [0:7];
            sorted[0]=1; sorted[1]=2; sorted[2]=3; sorted[3]=5;
            sorted[4]=6; sorted[5]=7; sorted[6]=8; sorted[7]=9;

            for (i = 0; i < 8; i = i + 1) begin
                got = DUT.DMEM.mem[128 + i];
                exp = sorted[i];
                if (got !== exp) begin
                    $display("  FAIL arr[%0d]: got %0d, expected %0d", i, got, exp);
                    errors = errors + 1;
                end else begin
                    $display("  PASS arr[%0d] = %0d", i, got);
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

`timescale 1ns / 1ps

module booth_multiplier_tb;

    parameter N = 8;

    reg clk;
    reg rst;
    reg start;

    reg signed [N-1:0] multiplicand;
    reg signed [N-1:0] multiplier;

    wire signed [(2*N)-1:0] product;
    wire busy;
    wire done;

    integer passed;
    integer failed;
    integer total;
    integer a;
    integer b;
    integer cycles;
    integer i;

    reg signed [(2*N)-1:0] expected;

    booth_multiplier #(.N(N)) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .product(product),
        .busy(busy),
        .done(done)
    );

    always #5 clk = ~clk;

    // Wait for reset to take effect
    task apply_reset;
        begin
            @(negedge clk);
            rst = 1;
            start = 0;

            @(posedge clk);
            #1;

            if (busy !== 0 || done !== 0 || product !== 0) begin
                $display("FAIL: reset behavior");
                failed = failed + 1;
            end
            else begin
                $display("PASS: reset behavior");
                passed = passed + 1;
            end

            @(negedge clk);
            rst = 0;
        end
    endtask

    // One multiplication transaction
    task run_test;
        input integer x;
        input integer y;
        integer elapsed;
        reg timed_out;
        begin
            @(negedge clk);

            multiplicand = x;
            multiplier   = y;
            expected     = x * y;
            start        = 1;

            @(negedge clk);
            start = 0;

            elapsed = 0;
            timed_out = 0;

            while ((done !== 1'b1) && (elapsed < N+3)) begin
                @(negedge clk);
                elapsed = elapsed + 1;
            end

            if (done !== 1'b1) begin
                $display("FAIL: timeout for %0d * %0d", x, y);
                failed = failed + 1;
                timed_out = 1;
            end
            else if (product !== expected) begin
                $display(
                    "FAIL: %0d * %0d: got %0d, expected %0d",
                    x, y, $signed(product), $signed(expected)
                );
                failed = failed + 1;
            end
            else begin
                passed = passed + 1;
            end

            total = total + 1;

            if (!timed_out && (done === 1'b1)) begin
                if (busy !== 1'b0) begin
                    $display("FAIL: busy did not clear");
                    failed = failed + 1;
                end

                // done must deassert on the following clock
                @(negedge clk);

                if (done !== 1'b0) begin
                    $display("FAIL: done is not a one-cycle pulse");
                    failed = failed + 1;
                end
            end
        end
    endtask

    // Exhaustive arithmetic test
    task exhaustive_test;
        integer x;
        integer y;
        integer elapsed;
        reg timed_out;
        begin
            $display("Starting exhaustive test: 65536 pairs");

            for (x = -128; x <= 127; x = x + 1) begin
                for (y = -128; y <= 127; y = y + 1) begin
                    @(negedge clk);

                    multiplicand = x;
                    multiplier   = y;
                    expected     = x * y;
                    start        = 1;

                    @(negedge clk);
                    start = 0;

                    elapsed = 0;
                    timed_out = 0;

                    while ((done !== 1'b1) &&
                           (elapsed < N+3)) begin
                        @(negedge clk);
                        elapsed = elapsed + 1;
                    end

                    if (done !== 1'b1) begin
                        $display(
                            "FAIL timeout: %0d * %0d", x, y
                        );
                        failed = failed + 1;
                        timed_out = 1;
                    end
                    else if (product !== expected) begin
                        $display(
                            "FAIL: %0d * %0d: got %0d expected %0d",
                            x, y, $signed(product), $signed(expected)
                        );
                        failed = failed + 1;
                    end
                    else begin
                        passed = passed + 1;
                    end

                    total = total + 1;

                    if (!timed_out && (done === 1'b1)) begin
                        @(negedge clk);
                    end

                    if (((x + 128) * 256 + y + 129) % 4096 == 0)
                        $display("Progress: x = %0d, y = %0d", x, y);
                end
            end

            $display("Exhaustive arithmetic test completed.");
        end
    endtask

    // Reset during an active multiplication
    task reset_during_operation;
        begin
            @(negedge clk);
            multiplicand = 23;
            multiplier = 7;
            start = 1;

            @(negedge clk);
            start = 0;

            // Allow the operation to enter its busy state
            repeat (2) @(negedge clk);

            if (busy !== 1'b1) begin
                $display("FAIL: DUT did not enter busy state");
                failed = failed + 1;
            end
            else begin
                rst = 1;

                @(posedge clk);
                #1;

                if (busy !== 0 || done !== 0 || product !== 0) begin
                    $display("FAIL: reset during operation");
                    failed = failed + 1;
                end
                else begin
                    $display("PASS: reset during operation");
                    passed = passed + 1;
                end

                @(negedge clk);
                rst = 0;
            end
        end
    endtask

    // Start asserted while busy must not corrupt operation
    task start_while_busy;
        begin
            @(negedge clk);
            multiplicand = 12;
            multiplier = -5;
            expected = -60;
            start = 1;

            @(negedge clk);
            start = 0;

            repeat (2) @(negedge clk);

            if (busy !== 1'b1) begin
                $display("FAIL: operation not busy");
                failed = failed + 1;
            end
            else begin
                // Attempt another start while busy
                multiplicand = 9;
                multiplier = 9;
                start = 1;

                @(negedge clk);
                start = 0;

                cycles = 0;

                while ((done !== 1'b1) && (cycles < N+3)) begin
                    @(negedge clk);
                    cycles = cycles + 1;
                end

                if (done !== 1'b1 || product !== expected) begin
                    $display("FAIL: start while busy");
                    failed = failed + 1;
                end
                else begin
                    $display("PASS: start while busy ignored");
                    passed = passed + 1;
                end
            end

            @(negedge clk);
        end
    endtask

    // Main test sequence
    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        multiplicand = 0;
        multiplier = 0;

        passed = 0;
        failed = 0;
        total = 0;

        repeat (2) @(negedge clk);
        rst = 0;

        $display("Starting directed arithmetic tests");

        run_test(3, 2);
        run_test(-3, 2);
        run_test(3, -2);
        run_test(-3, -2);
        run_test(0, 25);
        run_test(127, 127);
        run_test(-128, 1);
        run_test(-128, -1);
        run_test(-128, 127);
        run_test(127, -128);
        run_test(-128, -128);

        $display("Starting reset tests");
        apply_reset;
        reset_during_operation;

        $display("Starting busy/start test");
        start_while_busy;

        $display("Starting back-to-back tests");
        run_test(11, 13);
        run_test(-17, 6);
        run_test(-9, -12);
        run_test(0, -128);

        exhaustive_test;

        $display("----------------------------------------");
        $display("Total arithmetic transactions: %0d", total);
        $display("Checks passed: %0d", passed);
        $display("Checks failed: %0d", failed);
        $display("----------------------------------------");

        if (failed == 0)
            $display("OVERALL RESULT: PASS");
        else
            $display("OVERALL RESULT: FAIL");

        $finish;
    end

    // Global timeout: protects against a hung simulation
    initial begin
        #10000000;
        $display("FATAL: global simulation timeout");
        $finish;
    end

endmodule

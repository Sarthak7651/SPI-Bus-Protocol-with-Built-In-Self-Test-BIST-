`timescale 1ns / 1ps

module tb_bist_ctrl;

    // ============================================================
    // 1. PARAMETERS
    // ============================================================
    parameter DATA_WIDTH  = 8;
    parameter WORD_COUNT  = 8;
    parameter TIMEOUT_VAL = 512;
    parameter CLK_PERIOD  = 10;   // 100 MHz
    parameter SPI_DELAY   = 30;   // Cycles to simulate one SPI transfer
    parameter MAX_WAIT    = 800;  // Polling timeout per BIST run

    // Golden Expected Signatures
    parameter [7:0] EXP_MODE0 = 8'h00;
    parameter [7:0] EXP_MODE1 = 8'h00;
    parameter [7:0] EXP_MODE2 = 8'h04;

    // ============================================================
    // 2. SIGNALS
    // ============================================================
    reg             clk, rst_n;

    // Host / Register File Interface
    reg             bist_start;
    reg  [1:0]      bist_mode;
    reg  [7:0]      bist_sig_exp;
    wire            bist_pass;
    wire            bist_fail;
    wire            bist_busy;
    wire [3:0]      err_code;

    // SPI Master Model Interface
    wire            spi_en_dut;
    reg             spi_done_m;
    reg  [7:0]      rx_data_m;
    wire [7:0]      bist_tx;

    // LFSR & MISR Interface
    wire            lfsr_seed_load_dut, lfsr_en_dut;
    wire [7:0]      lfsr_data_w;
    wire            misr_en_dut, misr_rst_dut;
    wire [7:0]      misr_sig_w;
    wire            loopback_en;

    // Test Tracking Counters
    integer pass_cnt = 0, fail_cnt = 0, test_num = 0;

    // ============================================================
    // 3. DEVICE UNDER TEST (DUT)
    // ============================================================
    bist_ctrl #(
        .DATA_WIDTH (DATA_WIDTH),
        .WORD_COUNT (WORD_COUNT),
        .TIMEOUT_VAL(TIMEOUT_VAL)
    ) DUT (
        .clk           (clk),
        .rst_n         (rst_n),
        .bist_start    (bist_start),
        .bist_mode     (bist_mode),
        .bist_sig_exp  (bist_sig_exp),
        .bist_pass     (bist_pass),
        .bist_fail     (bist_fail),
        .bist_busy     (bist_busy),
        .err_code      (err_code),
        .spi_en        (spi_en_dut),
        .spi_done      (spi_done_m),
        .rx_data       (rx_data_m),
        .bist_tx       (bist_tx),
        .lfsr_seed_load(lfsr_seed_load_dut),
        .lfsr_en       (lfsr_en_dut),
        .lfsr_data     (lfsr_data_w),
        .misr_en       (misr_en_dut),
        .misr_rst      (misr_rst_dut),
        .misr_sig      (misr_sig_w),
        .loopback_en   (loopback_en)
    );

    // ============================================================
    // 4. BEHAVIORAL MODELS (SPI, LFSR, MISR)
    // ============================================================

    // Model 1: SPI Master Loopback Echo
    reg [7:0] spi_dly_cnt;
    reg       spi_active;
    reg [7:0] tx_latch;

    always @(posedge clk) begin
        spi_done_m <= 1'b0;
        if (!rst_n) begin
            spi_active  <= 1'b0;
            spi_dly_cnt <= 8'd0;
            rx_data_m   <= 8'h00;
        end else if (spi_en_dut && !spi_active) begin
            spi_active  <= 1'b1;
            spi_dly_cnt <= SPI_DELAY - 1;
            tx_latch    <= bist_tx;
        end else if (spi_active) begin
            if (spi_dly_cnt == 8'd0) begin
                spi_done_m <= 1'b1;
                rx_data_m  <= tx_latch; // Echo back transmitted byte
                spi_active <= 1'b0;
            end else begin
                spi_dly_cnt <= spi_dly_cnt - 8'd1;
            end
        end
    end

    // Model 2: LFSR Pattern Generator
    reg [7:0] lfsr_reg;
    wire lfsr_fb = lfsr_reg[7] ^ lfsr_reg[5] ^ lfsr_reg[4] ^ lfsr_reg[3];

    always @(posedge clk) begin
        if (!rst_n || lfsr_seed_load_dut)
            lfsr_reg <= 8'h01;
        else if (lfsr_en_dut)
            lfsr_reg <= {lfsr_reg[6:0], lfsr_fb};
    end
    assign lfsr_data_w = lfsr_reg;

    // Model 3: MISR Signature Compressor
    reg [7:0] misr_reg;

    always @(posedge clk) begin
        if (!rst_n || misr_rst_dut)
            misr_reg <= 8'h00;
        else if (misr_en_dut)
            misr_reg <= {misr_reg[6:0], misr_reg[7]} ^ rx_data_m;
    end
    assign misr_sig_w = misr_reg;

    // Clock Generator
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ============================================================
    // 5. TEST BENCH TASKS
    // ============================================================

    // Task 1: Single Value Equality Checker
    task check_val;
        input [255:0] label;
        input integer got;
        input integer exp;
        begin
            test_num = test_num + 1;
            if (got === exp) begin
                $display("  [PASS] Test %02d : %-35s | Value = 0x%0X", test_num, label, got);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  [FAIL] Test %02d : %-35s | Got 0x%0X, Exp 0x%0X", test_num, label, got, exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // Task 2: BIST Run Sequencer & Verification
    task run_bist;
        input [7:0]   sig;
        input [1:0]   mode;
        input         expect_pass;
        input [255:0] label;
        integer       i;
        reg           done;
        begin
            bist_sig_exp = sig;
            bist_mode    = mode;

            // Trigger Start Pulse
            @(posedge clk); #1; bist_start = 1'b1;
            @(posedge clk); #1; bist_start = 1'b0;

            // Poll until test completes or times out
            done = 0;
            for (i = 0; i < MAX_WAIT && !done; i = i + 1) begin
                @(posedge clk); #1;
                if (bist_pass || bist_fail) done = 1;
            end

            test_num = test_num + 1;

            // Evaluate Results
            if (expect_pass && done && bist_pass && !bist_fail) begin
                $display("  [PASS] Test %02d : %-35s | Pass=1, Err=%0d", test_num, label, err_code);
                pass_cnt = pass_cnt + 1;
            end else if (!expect_pass && done && bist_fail && !bist_pass && err_code == 4'h1) begin
                $display("  [PASS] Test %02d : %-35s | Fail=1, Err=1 (Expected Failure)", test_num, label);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  [FAIL] Test %02d : %-35s | Pass=%0d, Fail=%0d, Err=%0d", 
                         test_num, label, bist_pass, bist_fail, err_code);
                fail_cnt = fail_cnt + 1;
            end

            repeat(5) @(posedge clk); #1; // Wait for IDLE settle
        end
    endtask

    // ============================================================
    // 6. MAIN TEST EXECUTION
    // ============================================================
    initial begin
        // Reset and Initial values
        rst_n        = 1'b0;
        bist_start   = 1'b0;
        bist_mode    = 2'b00;
        bist_sig_exp = 8'h00;

        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(3) @(posedge clk); #1;

        $display("=================================================");
        $display("          BIST CONTROLLER TESTBENCH             ");
        $display("=================================================");

        // --- GROUP 1: Reset State ---
        $display("\n--- Group 1: Reset State Verification ---");
        check_val("bist_busy after reset",   bist_busy,   0);
        check_val("bist_pass after reset",   bist_pass,   0);
        check_val("bist_fail after reset",   bist_fail,   0);
        check_val("loopback_en after reset", loopback_en, 0);

        // --- GROUP 2: Mode 0 (Fixed Pattern) ---
        $display("\n--- Group 2: Mode 0 (Fixed Pattern 0xA5) ---");
        run_bist(EXP_MODE0, 2'b00, 1'b1, "Mode 0 Correct Signature");
        run_bist(8'hFF,     2'b00, 1'b0, "Mode 0 Corrupted Signature");
        check_val("err_code=1 on mismatch",  err_code,    1);

        // --- GROUP 3: Mode 1 (Walking 1s) ---
        $display("\n--- Group 3: Mode 1 (Walking 1s) ---");
        run_bist(EXP_MODE1, 2'b01, 1'b1, "Mode 1 Correct Signature");
        run_bist(8'hAA,     2'b01, 1'b0, "Mode 1 Corrupted Signature");

        // --- GROUP 4: Mode 2 (PRBS / LFSR) ---
        $display("\n--- Group 4: Mode 2 (PRBS / LFSR) ---");
        run_bist(EXP_MODE2, 2'b10, 1'b1, "Mode 2 Correct Signature");
        run_bist(8'hBE,     2'b10, 1'b0, "Mode 2 Corrupted Signature");

        // --- GROUP 5: Back-to-Back BIST Runs ---
        $display("\n--- Group 5: Back-to-Back Execution ---");
        run_bist(EXP_MODE0, 2'b00, 1'b1, "Back-to-Back Run 1");
        run_bist(EXP_MODE0, 2'b00, 1'b1, "Back-to-Back Run 2");
        run_bist(EXP_MODE2, 2'b10, 1'b1, "Back-to-Back Run 3");

        // --- GROUP 6: Control Signal Verification ---
        // --- GROUP 6: Edge Cases & Handshaking ---
                $display("\n--- Group 6: Edge Cases & Handshaking ---");
                
                // Test: Trigger bist_start while BIST is busy
                bist_sig_exp = EXP_MODE0;
                bist_mode    = 2'b00;
        
                // Start 1st BIST run
                @(posedge clk); #1; bist_start = 1'b1;
                @(posedge clk); #1; bist_start = 1'b0;
        
                // Send a 2nd start pulse while busy (should be ignored by FSM)
                repeat(5) @(posedge clk); #1;
                bist_start = 1'b1;
                @(posedge clk); #1;
                bist_start = 1'b0;
        
                // Wait for BIST operation to finish (~240+ clock cycles required)
                wait(bist_pass || bist_fail);
                repeat(2) @(posedge clk); #1;
        
                // Verify FSM completed properly and returned to IDLE
                check_val("bist_busy returns to 0 after run", bist_busy, 0);
                check_val("bist_pass set after double-start", bist_pass, 1);

        // --- TEST SUMMARY ---
        $display("\n=================================================");
        $display(" RESULTS: %0d PASSED | %0d FAILED | %0d TOTAL", pass_cnt, fail_cnt, test_num);
        if (fail_cnt == 0)
            $display(" *** ALL TESTS PASSED SUCCESSFULLY ***");
        else
            $display(" *** DETECTED %0d FAILURES ***", fail_cnt);
        $display("=================================================\n");
        $finish;
    end

    // Simulation Watchdog (12 ms)
    initial begin
        #12000000;
        $display("\n[WATCHDOG ERROR] Simulation Timeout!");
        $finish;
    end

    // Dump Waveforms
    initial begin
        $dumpfile("bist_ctrl_tb.vcd");
        $dumpvars(0, tb_bist_ctrl);
    end

endmodule
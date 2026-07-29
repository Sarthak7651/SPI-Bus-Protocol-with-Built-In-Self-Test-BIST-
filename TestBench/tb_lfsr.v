
`timescale 1ns / 1ps

module tb_lfsr;

// ============================================================
//  PARAMETERS
// ============================================================
parameter DATA_WIDTH   = 8;
parameter CLK_PERIOD   = 10;
parameter SEQ_LEN      = 255;   // full maximal-length period

// ============================================================
//  DUT SIGNALS
// ============================================================
reg                   clk, rst_n;
reg                   seed_load;
reg  [DATA_WIDTH-1:0] seed_in;
reg                   en;
wire [DATA_WIDTH-1:0] lfsr_data;

// ============================================================
//  GOLDEN MODEL STORAGE
// ============================================================
reg [DATA_WIDTH-1:0] golden [0:SEQ_LEN-1];

// ============================================================
//  TEST TRACKING
// ============================================================
integer pass_cnt, fail_cnt, test_num;
integer i;

// ============================================================
//  DUT
// ============================================================
lfsr #(
    .DATA_WIDTH   (DATA_WIDTH),
    .DEFAULT_SEED (8'h01)
) DUT (
    .clk       (clk),
    .rst_n     (rst_n),
    .seed_load (seed_load),
    .seed_in   (seed_in),
    .en        (en),
    .lfsr_data (lfsr_data)
);

// ============================================================
//  CLOCK
// ============================================================
initial clk = 0;
always  #(CLK_PERIOD/2) clk = ~clk;

// ============================================================
//  TASK : check_val
// ============================================================
task check_val;
    input [255:0]         label;
    input [DATA_WIDTH-1:0] got;
    input [DATA_WIDTH-1:0] exp;
    begin
        test_num = test_num + 1;
        if (got === exp) begin
            $display("  [PASS] Test %0d : %-40s  got=0x%02X", test_num, label, got);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  [FAIL] Test %0d : %-40s  got=0x%02X exp=0x%02X",
                     test_num, label, got, exp);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

// ============================================================
//  MAIN TEST SEQUENCE
// ============================================================
initial begin
    // Load golden model
    $readmemh("lfsr_golden.mem", golden);

    // Initialise 
    rst_n     = 1'b0;
    seed_load = 1'b0;
    seed_in   = 8'h00;
    en        = 1'b0;
    pass_cnt  = 0;
    fail_cnt  = 0;
    test_num  = 0;

    repeat(5) @(posedge clk);
    rst_n = 1'b1;
    repeat(2) @(posedge clk); #1;

    $display("================================================");
    $display("  LFSR Testbench  (Polynomial x^8+x^6+x^5+x^4+1)");
    $display("================================================");

    
    //  GROUP 1 : Reset default seed
    
    $display("\n--- Group 1: Reset default seed ---");
    check_val("Default seed after reset", lfsr_data, 8'h01);

    
    //  GROUP 2 : Seed load - normal non-zero seed
    $display("\n--- Group 2: Seed load (non-zero) ---");

    @(posedge clk); #1;
    seed_load = 1'b1;
    seed_in   = 8'hC3;
    @(posedge clk); #1;
    seed_load = 1'b0;
    check_val("Load seed=C3", lfsr_data, 8'hC3);

    @(posedge clk); #1;
    seed_load = 1'b1;
    seed_in   = 8'h7E;
    @(posedge clk); #1;
    seed_load = 1'b0;
    check_val("Load seed=7E", lfsr_data, 8'h7E);

    
    //  GROUP 3 : Seed load - zero seed (Layer 1 lockout protection)
    //  Requesting seed_in=0 must NOT load 0; must load DEFAULT_SEED.
    
    $display("\n--- Group 3: Zero-seed lockout protection ---");

    @(posedge clk); #1;
    seed_load = 1'b1;
    seed_in   = 8'h00;         // Illegal request
    @(posedge clk); #1;
    seed_load = 1'b0;
    check_val("Zero seed ? forced to 01", lfsr_data, 8'h01);

    
    //  GROUP 4 : Full 255-state maximal-length sequence
    //  Reset LFSR to DEFAULT_SEED, then step through all 255
    //  states and compare against the golden model.
    
    $display("\n--- Group 4: Full 255-state sequence vs golden model ---");

    // Reload known seed to start the sequence cleanly
    @(posedge clk); #1;
    seed_load = 1'b1;
    seed_in   = 8'h01;
    @(posedge clk); #1;
    seed_load = 1'b0;

    // Check state 0 (the seed itself, before any shift)
    check_val("Sequence[0] = seed", lfsr_data, golden[0]);

    // Step through states 1 to 254 and compare
    for (i = 1; i < SEQ_LEN; i = i + 1) begin
        @(posedge clk); #1;
        en = 1'b1;
        @(posedge clk); #1;
        en = 1'b0;

        test_num = test_num + 1;
        if (lfsr_data === golden[i]) begin
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  [FAIL] Test %0d : Sequence[%0d]  got=0x%02X exp=0x%02X",
                     test_num, i, lfsr_data, golden[i]);
            fail_cnt = fail_cnt + 1;
        end
    end
    $display("  [INFO] Completed %0d-step sequence comparison (states 1..%0d)",
              SEQ_LEN-1, SEQ_LEN-1);
    $display("  [INFO] Sequence check: %0d passed inline, see summary for total", pass_cnt);

    
    //  GROUP 5 : Wrap-around - one more step returns to seed
    $display("\n--- Group 5: Wrap-around after 255 steps ---");

    @(posedge clk); #1;
    en = 1'b1;
    @(posedge clk); #1;
    en = 1'b0;
    check_val("Wraps back to seed=0x01", lfsr_data, 8'h01);

    
    //  GROUP 6 : Hold behaviour (en=0, seed_load=0)
    
    $display("\n--- Group 6: Hold when idle ---");

    @(posedge clk); #1;
    en = 1'b1;
    @(posedge clk); #1;
    en = 1'b0;              // now at sequence[1] = 0x02
    check_val("Value before hold", lfsr_data, 8'h02);

    repeat(5) @(posedge clk); #1;   // idle - en and seed_load both 0
    check_val("Value held (5 idle cycles)", lfsr_data, 8'h02);

    
    //  GROUP 7 : Self-healing - Layer 2 lockout protection
    //  Force the internal register to 0 via hierarchical path
    //  (simulates an SEU / soft error), then verify the LFSR
    //  recovers to DEFAULT_SEED on the next enabled edge
    //  instead of staying stuck at 0.
    
    $display("\n--- Group 7: Self-healing from forced all-zero state ---");

    @(posedge clk); #1;
    force DUT.shift_reg = 8'h00;    // simulate fault injection
    #1;
    check_val("Forced internal reg = 0", lfsr_data, 8'h00);
    release DUT.shift_reg;

    @(posedge clk); #1;
    en = 1'b1;
    @(posedge clk); #1;
    en = 1'b0;
    check_val("Self-healed to DEFAULT_SEED", lfsr_data, 8'h01);

    // Verify it continues correctly after healing (matches golden[1])
    @(posedge clk); #1;
    en = 1'b1;
    @(posedge clk); #1;
    en = 1'b0;
    check_val("Continues correctly post-heal", lfsr_data, golden[1]);

    
    //  FINAL SUMMARY
    $display("\n================================================");
    $display("  RESULTS : %0d PASSED | %0d FAILED | %0d TOTAL",
             pass_cnt, fail_cnt, test_num);
    if (fail_cnt == 0)
        $display("  *** ALL TESTS PASSED - LFSR verified maximal-length ***");
    else
        $display("  *** %0d FAILURE(S) - Check polynomial taps ***", fail_cnt);
    $display("================================================\n");

    $finish;
end

// ============================================================
//  WATCHDOG
// ============================================================
initial begin
    #200000;
    $display("[WATCHDOG] Timeout - Aborting.");
    $finish;
end

// ============================================================
//  WAVEFORM DUMP
// ============================================================
initial begin
    $dumpfile("lfsr_tb.vcd");
    $dumpvars(0, tb_lfsr);
end

endmodule
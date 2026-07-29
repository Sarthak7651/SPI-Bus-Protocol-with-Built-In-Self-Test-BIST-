`timescale 1ns / 1ps

module tb_spi_master;

    // 1. Parameters 
    parameter DATA_WIDTH = 8;
    parameter CLK_PERIOD = 10; // 100 MHz System Clock
    
    // 2. Testbench Signals
    reg                   clk;
    reg                   rst_n;
    reg                   spi_en;
    reg                   cpol;
    reg                   cpha;
    reg  [7:0]            clk_div;
    reg  [DATA_WIDTH-1:0] tx_data;
    
    wire [DATA_WIDTH-1:0] rx_data;
    wire                  busy;
    wire                  done;
    wire                  sclk;
    wire                  mosi;
    wire                  ss_n;
    wire                  miso;

    // Counters pass/fail 
    integer pass_count = 0;
    integer fail_count = 0;

    // 3. DUT 
        spi_master #(.DATA_WIDTH(DATA_WIDTH)) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .spi_en(spi_en),
        .cpol(cpol),
        .cpha(cpha),
        .clk_div(clk_div),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .mosi(mosi),
        .ss_n(ss_n),
        .miso(miso)
    );

    // 4. Clock Generation 
        initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // 5. MISO-MOSI Loopback Logic
    assign #1 miso = mosi;

    // 6. Test Task 
       task test_byte(input [7:0] test_data, input [40*8:1] test_name);
        begin
            // Data aur Enable signal setup karo
            tx_data = test_data;
            @(posedge clk);
            spi_en = 1'b1;
            
            @(posedge clk);
            spi_en = 1'b0; // Enable ko wapas 0 kar do
            
            // Transfer complete (done) hone ka wait karo
            @(posedge done);
            @(posedge clk); // Ek extra clock rx_data update hone ke liye

            
            if (rx_data === test_data) begin
                $display("[PASS] %s | Sent: %0h, Rcvd: %0h", test_name, test_data, rx_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s | Sent: %0h, Rcvd: %0h <--- ERROR!", test_name, test_data, rx_data);
                fail_count = fail_count + 1;
            end
            
            // Do transfers ke beech thoda gap
            repeat(5) @(posedge clk); 
        end
    endtask

    // 7. Main Test Sequence
    initial begin
        // A. Initial Setup (Reset apply karna)
        $display("\n==============================================");
        $display("   SPI MASTER (MODE 0 HARDWIRED) TESTBENCH");
        $display("==============================================\n");
        
        rst_n   = 1'b0; // Reset ON
        spi_en  = 1'b0;
        cpol    = 1'b0;
        cpha    = 1'b0;
        clk_div = 8'd4; // SCLK freq = 100MHz / (2*4) = 12.5 MHz
        tx_data = 8'h00;

        // Reset ko OFF karo thodi der baad
        repeat(5) @(posedge clk);
        rst_n = 1'b1; // Reset OFF
        repeat(5) @(posedge clk);

        // B. Standard Test Cases Run Karna
        $display("--- 1. Edge Case Tests (All 0s & All 1s) ---");
        test_byte(8'h00, "Test All Zeros     ");
        test_byte(8'hFF, "Test All Ones      ");

        $display("\n--- 2. Alternating Bits Tests ---");
        test_byte(8'hAA, "Test Pattern 1010  "); // 10101010
        test_byte(8'h55, "Test Pattern 0101  "); // 01010101

        $display("\n--- 3. Random Data Tests ---");
        test_byte(8'hA5, "Test Random 1      ");
        test_byte(8'h3C, "Test Random 2      ");
        test_byte(8'h81, "Test MSB/LSB High  ");

        // C. Robustness Test (Checking if CPOL/CPHA inputs are truly ignored)
        $display("\n--- 4. Robustness Tests (cpol=1, cpha=1) ---");
        cpol = 1'b1; // Inko 1 karke dekhte hain code change hota hai ya nahi
        cpha = 1'b1; 
        test_byte(8'h42, "Ignored CPOL/CPHA 1");
        test_byte(8'h7E, "Ignored CPOL/CPHA 2");

        // D. Final Report Print Karna
        $display("\n==============================================");
        $display("   TEST RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display("   STATUS: ALL TESTS PASSED SUCCESSFULLY! :)");
        else
            $display("   STATUS: TEST FAILED! Check Waveform.");
        $display("==============================================\n");

        $finish; // Simulation End
    end

    // 8. Waveform Generate karne ke liye
    initial begin
        $dumpfile("spi_waveform.vcd");
        $dumpvars(0, tb_spi_master);
    end

endmodule
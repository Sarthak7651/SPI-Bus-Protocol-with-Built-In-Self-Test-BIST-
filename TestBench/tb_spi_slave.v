`timescale 1ns / 1ps

module tb_spi_slave;

    parameter DATA_WIDTH     = 8;
    parameter CLK_PERIOD     = 10; // System clock = 100MHz (10ns)
    parameter SPI_CLK_PERIOD = 80; // SCLK period = 12.5MHz (8x system clock)

    // Testbench signals
    reg clk;
    reg rst_n;
    reg cpol;
    reg cpha;
    reg sclk_in;
    reg mosi;
    reg ss_n_in;
    reg [DATA_WIDTH-1:0] tx_data;

    wire miso;
    wire [DATA_WIDTH-1:0] rx_data;
    wire rx_done;

    // Test Counters
    integer pass_cnt = 0;
    integer fail_cnt = 0;
    integer test_num = 0;

    // Instantiate Unit Under Test (UUT)
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .cpol(cpol),
        .cpha(cpha),
        .sclk_in(sclk_in),
        .mosi(mosi),
        .miso(miso),
        .ss_n_in(ss_n_in),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    // -------------------------------------------------------------
    // System Clock Generator
    // -------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------
    // Helper Task: Result Checker
    // -------------------------------------------------------------
    task check_result(
        input [DATA_WIDTH-1:0] exp_m_rx,
        input [DATA_WIDTH-1:0] exp_s_rx,
        input [DATA_WIDTH-1:0] act_m_rx,
        input [DATA_WIDTH-1:0] act_s_rx,
        input [256*8:1] test_label
    );
        begin
            test_num = test_num + 1;
            if ((act_m_rx === exp_m_rx) && (act_s_rx === exp_s_rx)) begin
                $display("[PASS] Test %0d: %0s | Master Recv: 0x%02h, Slave Recv: 0x%02h", 
                         test_num, test_label, act_m_rx, act_s_rx);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] Test %0d: %0s | Master Recv: 0x%02h (Exp: 0x%02h), Slave Recv: 0x%02h (Exp: 0x%02h)", 
                         test_num, test_label, act_m_rx, exp_m_rx, act_s_rx, exp_s_rx);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // -------------------------------------------------------------
    // Helper Task: Normal Full 1-Byte SPI Transfer (Mode 0)
    // -------------------------------------------------------------
    task run_transfer(
        input [DATA_WIDTH-1:0] m_tx,
        input [DATA_WIDTH-1:0] s_tx,
        input [256*8:1] test_label
    );
        integer i;
        reg [DATA_WIDTH-1:0] m_rx;
        begin
            tx_data = s_tx;
            ss_n_in = 1'b0; // Assert Chip Select
            
            // Allow 4 clock cycles for slave synchronizer to detect ss_fall & pre-drive MSB
            #(CLK_PERIOD * 4);

            for (i = DATA_WIDTH - 1; i >= 0; i = i - 1) begin
                mosi = m_tx[i]; // Drive MOSI before rising edge
                #(SPI_CLK_PERIOD / 2);

                sclk_in = 1'b1; // SCLK Rising Edge -> Slave samples MOSI, Master samples MISO
                m_rx[i] = miso;
                #(SPI_CLK_PERIOD / 2);

                sclk_in = 1'b0; // SCLK Falling Edge -> Slave shifts next bit onto MISO
            end

            #(CLK_PERIOD * 4);
            ss_n_in = 1'b1; // Deassert Chip Select
            #(CLK_PERIOD * 4);

            check_result(s_tx, m_tx, m_rx, rx_data, test_label);
        end
    endtask

    // -------------------------------------------------------------
    // Helper Task: Mid-Transfer Early Abort Test
    // -------------------------------------------------------------
    task run_aborted_transfer(input [256*8:1] test_label);
        integer i;
        reg [DATA_WIDTH-1:0] old_rx_data;
        begin
            test_num = test_num + 1;
            old_rx_data = rx_data;

            tx_data = 8'hFF;
            ss_n_in = 1'b0;
            #(CLK_PERIOD * 4);

            // Send only 4 bits out of 8
            for (i = 0; i < 4; i = i + 1) begin
                mosi = i[0];
                #(SPI_CLK_PERIOD / 2);
                sclk_in = 1'b1;
                #(SPI_CLK_PERIOD / 2);
                sclk_in = 1'b0;
            end

            // Prematurely raise SS_N to trigger abort
            ss_n_in = 1'b1;
            #(CLK_PERIOD * 6);

            if (rx_data === old_rx_data && rx_done === 1'b0) begin
                $display("[PASS] Test %0d: %0s | Aborted successfully. Old rx_data preserved (0x%02h)",
                         test_num, test_label, rx_data);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] Test %0d: %0s | Abort failed! rx_data modified or rx_done pulsed.", test_num, test_label);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // -------------------------------------------------------------
    // Helper Task: Mid-Transfer Asynchronous Reset Test
    // -------------------------------------------------------------
    task run_reset_during_transfer(input [256*8:1] test_label);
        integer i;
        begin
            test_num = test_num + 1;

            tx_data = 8'hBB;
            ss_n_in = 1'b0;
            #(CLK_PERIOD * 4);

            // Send 3 clock cycles
            for (i = 0; i < 3; i = i + 1) begin
                mosi = 1'b1;
                #(SPI_CLK_PERIOD / 2);
                sclk_in = 1'b1;
                #(SPI_CLK_PERIOD / 2);
                sclk_in = 1'b0;
            end

            // Assert active-low reset mid-transfer
            rst_n = 1'b0;
            #(CLK_PERIOD * 3);
            rst_n = 1'b1;
            ss_n_in = 1'b1;
            #(CLK_PERIOD * 5);

            if (rx_data === 8'h00 && rx_done === 1'b0 && miso === 1'b0) begin
                $display("[PASS] Test %0d: %0s | Module correctly reset state machine mid-transfer",
                         test_num, test_label);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] Test %0d: %0s | Reset during transfer failed!", test_num, test_label);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // -------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------
    initial begin
        // Signal Initialization
        rst_n   = 1'b0;
        cpol    = 1'b0;
        cpha    = 1'b0;
        sclk_in = 1'b0;
        mosi    = 1'b0;
        ss_n_in = 1'b1;
        tx_data = 8'h00;

        // Apply Reset
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);

        $display("=========================================================");
        $display("       SPI SLAVE COMPREHENSIVE TESTBENCH SUITE          ");
        $display("=========================================================");

        // --- GROUP 1: Standard Data Patterns ---
        $display("\n--- GROUP 1: Data Pattern Checks ---");
        run_transfer(8'hA5, 8'h3C, "Basic Exchange (M:0xA5, S:0x3C)");
        run_transfer(8'h00, 8'hFF, "All Zeros vs All Ones");
        run_transfer(8'hFF, 8'h00, "All Ones vs All Zeros");
        run_transfer(8'h55, 8'hAA, "Alternating Bits (0x55 / 0xAA)");
        run_transfer(8'h12, 8'hE3, "Random Pattern (0x12 / 0xE3)");

        // --- GROUP 2: Unused Configuration Pins (CPOL/CPHA Robustness) ---
        $display("\n--- GROUP 2: CPOL / CPHA Input Robustness ---");
        cpol = 1'b0; cpha = 1'b1;
        run_transfer(8'hB4, 8'h4B, "Driven CPOL=0, CPHA=1");

        cpol = 1'b1; cpha = 1'b0;
        run_transfer(8'hC3, 8'h3C, "Driven CPOL=1, CPHA=0");

        cpol = 1'b1; cpha = 1'b1;
        run_transfer(8'h7E, 8'h81, "Driven CPOL=1, CPHA=1");

        cpol = 1'b0; cpha = 1'b0; // Restore defaults

        // --- GROUP 3: Back-to-Back Transfers ---
        $display("\n--- GROUP 3: Consecutive / Back-to-Back Transfers ---");
        run_transfer(8'h11, 8'h22, "Back-to-back Transfer #1");
        run_transfer(8'h33, 8'h44, "Back-to-back Transfer #2");

        // --- GROUP 4: Abort & Fault Recovery ---
        $display("\n--- GROUP 4: Abort & Fault Recovery ---");
        run_aborted_transfer("Early SS_N Deassertion (Abort after 4 bits)");
        run_transfer(8'h99, 8'h66, "Recovery Transfer Post-Abort");

        // --- GROUP 5: Mid-Transfer System Reset ---
        $display("\n--- GROUP 5: Mid-Transfer Asynchronous Reset ---");
        run_reset_during_transfer("Assert Reset during active transmission");
        run_transfer(8'h88, 8'h77, "Recovery Transfer Post-Reset");

        // --- Final Summary ---
        $display("\n=========================================================");
        $display(" TEST RESULTS SUMMARY: %0d Passed, %0d Failed (out of %0d)", 
                 pass_cnt, fail_cnt, test_num);
        if (fail_cnt == 0)
            $display(" >>> ALL COMPREHENSIVE TESTS PASSED SUCCESSFULLY! <<<");
        else
            $display(" >>> SOME TESTS FAILED! PLEASE CHECK THE LOG ABOVE. <<<");
        $display("=========================================================");

        $finish;
    end

endmodule
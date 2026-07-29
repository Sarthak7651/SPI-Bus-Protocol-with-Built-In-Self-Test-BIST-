`timescale 1ns / 1ps

module tb_spi_system;

    // System Signals
    reg clk;
    reg rst_n;

    // Fixed SPI Mode 0 Parameters (CPOL = 0, CPHA = 0)
    localparam CPOL = 1'b0;
    localparam CPHA = 1'b0;

    // Clock Divider Configuration
    reg [7:0] clk_div;

    // Master Interfaces
    reg        spi_en;
    reg  [7:0] master_tx_data;
    wire [7:0] master_rx_data;
    wire       master_busy;
    wire       master_done;

    // Slave Interfaces
    reg  [7:0] slave_tx_data;
    wire [7:0] slave_rx_data;
    wire       slave_done;

    // Internal SPI Bus Wires
    wire sclk;
    wire mosi;
    wire miso;
    wire ss_n;

    // Test Status Tracking
    integer pass_cnt = 0;
    integer fail_cnt = 0;
    integer test_num = 0;
    
    // Loop Variable & Random Variables
    integer i;
    reg [7:0] rand_m_tx;
    reg [7:0] rand_s_tx;

    // ========================================================
    //  Module Instantiations (Hardwired to CPOL=0, CPHA=0)
    // ========================================================

    spi_master #(
        .DATA_WIDTH(8)
    ) u_master (
        .clk(clk),.rst_n(rst_n),.spi_en(spi_en),.cpol(CPOL),
        .cpha(CPHA),.clk_div(clk_div),.tx_data(master_tx_data),
        .rx_data(master_rx_data),.busy(master_busy),
        .done(master_done),.sclk(sclk),.mosi(mosi),
        .ss_n(ss_n),.miso(miso)
    );

    spi_slave #(
        .DATA_WIDTH(8)
    ) u_slave (
        .clk(clk),.rst_n(rst_n),.cpol(CPOL),.cpha(CPHA),
        .sclk_in(sclk),.mosi(mosi),.miso(miso),.ss_n_in(ss_n),
        .tx_data(slave_tx_data),.rx_data(slave_rx_data),.rx_done(slave_done)
    );

    // ========================================================
    //  Clock Generation (100 MHz System Clock)
    // ========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //  Mode 0 Transfer Task
    task run_mode0_transfer(input [7:0] m_tx, input [7:0] s_tx);
        begin
            test_num = test_num + 1;
            master_tx_data = m_tx;
            slave_tx_data  = s_tx;

            // Trigger Master Start Pulse
            @(posedge clk);
            spi_en = 1;
            @(posedge clk);
            spi_en = 0;

            // Wait for BOTH Master and Slave to complete
            fork
                wait(master_done == 1'b1);
                wait(slave_done  == 1'b1);
            join

            // Allow extra clock cycles for output registers to settle
            repeat(2) @(posedge clk);

            // Check and Display Results
            if ((slave_rx_data === m_tx) && (master_rx_data === s_tx)) begin
                $display("[PASS] Iteration %02d | Master Sent: %0X -> Slave Recv: %0X | Slave Sent: %0X -> Master Recv: %0X",
                         test_num, m_tx, slave_rx_data, s_tx, master_rx_data);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] Iteration %02d | Master Sent: %0X -> Slave Recv: %0X (Exp: %0X) | Slave Sent: %0X -> Master Recv: %0X (Exp: %0X)",
                         test_num, m_tx, slave_rx_data, m_tx, s_tx, master_rx_data, s_tx);
                fail_cnt = fail_cnt + 1;
            end

            repeat(5) @(posedge clk);
        end
    endtask

    // ========================================================
    //  Test Stimulus
    // ========================================================
    initial begin
        // 1. Initialize Signals
        rst_n          = 0;
        spi_en         = 0;
        clk_div        = 8'd4; // SCLK half-period = 4 system clocks
        master_tx_data = 8'h00;
        slave_tx_data  = 8'h00;

        // 2. Reset Sequence
        #20;
        rst_n = 1;
        #20;

        $display("\n=========================================================");
        $display("   SPI System Testbench - 15 Random Iterations (Mode 0)   ");
        $display("=========================================================\n");

        // 3. Run 15 Randomized Loop Iterations
        for (i = 1; i <= 15; i = i + 1) begin
            rand_m_tx = $urandom_range(0, 255); // Generate random 8-bit Master data
            rand_s_tx = $urandom_range(0, 255); // Generate random 8-bit Slave data
            run_mode0_transfer(rand_m_tx, rand_s_tx);
        end

        // 4. Final Results
        $display("\n=========================================================");
        $display(" TEST STATUS: %0d Passed, %0d Failed (out of %0d Total)", pass_cnt, fail_cnt, test_num);
        if (fail_cnt == 0)
            $display(" >>> ALL 15 RANDOMIZED TESTS PASSED SUCCESSFULLY! <<<");
        else
            $display(" >>> SOME TESTS FAILED! CHECK LOG ABOVE. <<<");
        $display("=========================================================\n");

        #50;
        $finish;
    end

endmodule
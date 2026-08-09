// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef TB_TOP_SV
`define TB_TOP_SV

`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "spi_if.sv"
`include "spi_base_test.sv"

module tb_top;

    //clock generation - 100 MHz 

    bit clk;
    initial clk = 0;
    always #5 clk = ~clk;   // 10 ns period = 100 MHz


    spi_if vif(clk);


    initial begin
        vif.rst_n = 0;
        repeat (5) @(posedge clk);
        vif.rst_n = 1;
    end

  //normal transfer loop back
    assign vif.spi_miso = vif.spi_mosi;


    //DUT

    spi_bist_top #(
        .DATA_WIDTH   (8),
        .ADDR_WIDTH   (4),
        .WORD_COUNT   (8),
        .TIMEOUT_VAL  (512),
        .LFSR_SEED_VAL(8'h01)
    ) dut (
        .clk             (clk),
        .rst_n           (vif.rst_n),
        .wr_en           (vif.wr_en),
        .wr_addr         (vif.wr_addr),
        .wr_data         (vif.wr_data),
        .rd_addr         (vif.rd_addr),
        .rd_data         (vif.rd_data),
        .spi_sclk        (vif.spi_sclk),
        .spi_mosi        (vif.spi_mosi),
        .spi_ss_n        (vif.spi_ss_n),
        .spi_miso        (vif.spi_miso),
        .bist_pass_pulse (vif.bist_pass_pulse),
        .bist_fail_pulse (vif.bist_fail_pulse)
    );

//monitor
    assign vif.mon_rx_data      = dut.rx_data_m_w;
    assign vif.mon_done         = dut.done_w;
    assign vif.mon_bist_pass    = dut.bist_pass_w;
    assign vif.mon_bist_fail    = dut.bist_fail_w;
    assign vif.mon_err_code     = dut.err_code_w;
    assign vif.mon_bist_sig_act = dut.misr_sig_w;
    assign vif.mon_bist_busy    = dut.bist_busy_w;   // tells monitor bist is active


//SS_abort request

    always @(posedge vif.ss_abort_req) begin
        repeat (vif.ss_abort_bits) @(posedge clk);
        force dut.u_master.ss_n = 1'b1;
        @(posedge clk);
        release dut.u_master.ss_n;
        vif.ss_abort_done = 1;
        @(posedge clk);
        vif.ss_abort_done = 0;
    end


    //fault-injection request

    always @(posedge vif.fault_inject_req) begin
        repeat (20) @(posedge clk);
        force dut.slave_miso_w = 1'b0;
        repeat (2) @(posedge clk);
        release dut.slave_miso_w;
        vif.fault_inject_done = 1;
        @(posedge clk);
        vif.fault_inject_done = 0;
    end


    //run test
    // default test is the master one, so plain "run -all" gives
    // the full coverage number. can still override with
    // +UVM_TESTNAME=test_tc01_basic_xfer etc for a single test

    initial begin
        uvm_config_db #(virtual spi_if)::set(null, "*", "vif", vif);
        run_test("test_master_regression");
    end

endmodule

`endif

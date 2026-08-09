// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef SPI_MONITOR_SV
`define SPI_MONITOR_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "spi_seq_item.sv"

//moniter class 

class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)

    virtual spi_if vif;

    //analysis port connection 

    uvm_analysis_port #(spi_seq_item) ap;

    localparam A_CTRL   = 4'h0;
    localparam A_TXDATA = 4'h2;
    localparam A_SIGEXP = 4'h4;

    // registers for copy data 

    bit [7:0]    shadow_tx_data;
    bit [1:0]    shadow_bist_mode;
    bit [7:0]    shadow_sig_exp;

    // remembering the previous status bit

    bit prev_done;
    bit prev_bist_pass;
    bit prev_bist_fail;

    function new(string name = "spi_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual spi_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "couldn't find vif in config_db - did tb_top set it?")
    endfunction

    task run_phase(uvm_phase phase);
        prev_done      = 0;
        prev_bist_pass = 0;
        prev_bist_fail = 0;

        forever begin
            @(posedge vif.clk);

            watch_writes();
            watch_for_normal_done();
            watch_for_bist_result();

            // updateing previous registers for tracking

            prev_done      = vif.mon_done;
            prev_bist_pass = vif.mon_bist_pass;
            prev_bist_fail = vif.mon_bist_fail;
        end
    endtask


//copying the written data into the shadow registers

    task watch_writes();
        if (vif.wr_en) begin
            case (vif.wr_addr)
                A_TXDATA: shadow_tx_data <= vif.wr_data[7:0];
                A_CTRL:   shadow_bist_mode <= vif.wr_data[4:3];
                A_SIGEXP: shadow_sig_exp <= vif.wr_data[7:0];
                default: ; 
            endcase
        end
    endtask


    // normal transfer  DONE go from 0 to 1
    // also check bist is not busy, done pulses during a bist run
    // are internal bist bytes, not a real normal transfer
    task watch_for_normal_done();
        if (vif.mon_done && !prev_done && !vif.mon_bist_busy) begin
            spi_seq_item item;
            item = spi_seq_item::type_id::create("mon_item");
            item.kind             = NORMAL_XFER;
            item.tx_data          = shadow_tx_data;
            item.observed_rx_data = vif.mon_rx_data;
            item.observed_done    = 1;
            `uvm_info("MON", $sformatf("saw a normal transfer finish: tx_data=0x%0h rx_data=0x%0h",
                                         shadow_tx_data, vif.mon_rx_data), UVM_MEDIUM)
            ap.write(item);
        end
    endtask


    // BIST run - bist pass or fail
    task watch_for_bist_result();
        if (vif.mon_bist_pass && !prev_bist_pass) begin
            spi_seq_item item;
            item = spi_seq_item::type_id::create("mon_item");
            item.kind                  = BIST_RUN;
            item.bist_mode              = bist_mode_e'(shadow_bist_mode);
            item.bist_sig_exp           = shadow_sig_exp;   
            
            item.observed_bist_pass     = 1;
            item.observed_bist_fail     = 0;
            item.observed_bist_sig_act   = vif.mon_bist_sig_act;
            item.observed_err_code      = vif.mon_err_code;
            `uvm_info("MON", $sformatf("saw BIST PASS, mode=%0d sig_act=0x%0h",
                                         shadow_bist_mode, vif.mon_bist_sig_act), UVM_MEDIUM)
            ap.write(item);
        end

        if (vif.mon_bist_fail && !prev_bist_fail) begin
            spi_seq_item item;
            item = spi_seq_item::type_id::create("mon_item");
            item.kind                  = BIST_RUN;
            item.bist_mode              = bist_mode_e'(shadow_bist_mode);
            item.bist_sig_exp           = shadow_sig_exp;   // same reason as above
            item.observed_bist_pass     = 0;
            item.observed_bist_fail     = 1;
            item.observed_bist_sig_act   = vif.mon_bist_sig_act;
            item.observed_err_code      = vif.mon_err_code;
            `uvm_info("MON", $sformatf("saw BIST FAIL, mode=%0d err_code=%0d",
                                         shadow_bist_mode, vif.mon_err_code), UVM_MEDIUM)
            ap.write(item);
        end
    endtask

endclass

`endif

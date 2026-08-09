// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef SPI_DRIVER_SV
`define SPI_DRIVER_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "spi_seq_item.sv"

class spi_driver extends uvm_driver #(spi_seq_item);
    `uvm_component_utils(spi_driver)

    virtual spi_if vif;   // interface 

    // this port sends out the item BEFORE we drive it, so
    // coverage gets the real kind and fields the sequence asked
    // for. monitor only ever sees NORMAL_XFER or BIST_RUN back
    // (that is all it can tell from the pins) so coverage was
    // stuck low without this
    uvm_analysis_port #(spi_seq_item) req_ap;

    // register addresses
    localparam A_CTRL    = 4'h0;
    localparam A_STATUS  = 4'h1;
    localparam A_TXDATA  = 4'h2;
    localparam A_RXDATA  = 4'h3;
    localparam A_SIGEXP  = 4'h4;
    localparam A_SIGACT  = 4'h5;

    // how many times to poll value
    localparam int POLL_LIMIT = 5000;

    function new(string name = "spi_driver", uvm_component parent = null);
        super.new(name, parent);
        req_ap = new("req_ap", this);
    endfunction

    // build_phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual spi_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "couldn't find vif in config_db - did tb_top set it?")
    endfunction

    // run_phase 

    task run_phase(uvm_phase phase);
        spi_seq_item req;

        
        wait(vif.rst_n == 1'b1); //wait for hardware to come out fo reset first
        @(posedge vif.clk);
        
        forever begin
            seq_item_port.get_next_item(req);
            req_ap.write(req);   // send the real request out for coverage
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    // basic register write 

    task reg_write(bit [3:0] addr, bit [15:0] data);
        @(posedge vif.clk);
        vif.wr_en   = 1;
        vif.wr_addr = addr;
        vif.wr_data = data;
        @(posedge vif.clk);
        vif.wr_en   = 0;
    endtask

    // basic register read
    task reg_read(bit [3:0] addr, output bit [15:0] data);
        vif.rd_addr = addr;
        #1;
        data = vif.rd_data;
    endtask



    // MISR signature genration 

    function bit [7:0] compute_golden_sig(bist_mode_e mode);
        bit [7:0] sig;
        bit [7:0] lfsr;
        bit [7:0] pattern;
        sig  = 8'h00;
        lfsr = 8'h01;   

        for (int i = 0; i < 8; i++) begin
            case (mode)
                BIST_MODE_LOOPBACK: pattern = 8'hA5;
                BIST_MODE_WALK1:    pattern = (8'h01 << i);
                BIST_MODE_PRBS: begin
                    pattern = lfsr;
                    lfsr = {lfsr[6:0], lfsr[7]^lfsr[5]^lfsr[4]^lfsr[3]};
                end
                default: pattern = 8'h00;
            endcase
            // rotate sig left by 1, then XOR in the pattern byte
            sig = {sig[6:0], sig[7]} ^ pattern;
        end
        return sig;
    endfunction



    // calling the right driver according to the TC
    task drive_item(spi_seq_item item);
        case (item.kind)
            NORMAL_XFER:            drive_normal_xfer(item);
            SS_ABORT_XFER:           drive_ss_abort(item);
            BIST_RUN:                drive_bist_run(item, 0);
            BIST_FAULT_INJECT:       drive_bist_run(item, 1);
            default: `uvm_error("DRV", $sformatf("unknown item kind: %s", item.kind.name()))
        endcase
    endtask


    //TC01 normal transaction

    task drive_normal_xfer(spi_seq_item item);
        bit [15:0] status;
        int polls;

        reg_write(A_TXDATA, {8'h00, item.tx_data});
        reg_write(A_CTRL, {item.clk_div, 7'h00, 1'b1});  // clk_div + SPI_EN=1

        polls = 0;
        status = 0;
        while (!status[1] && polls < POLL_LIMIT) begin   // wait for DONE bit
            reg_read(A_STATUS, status);
            @(posedge vif.clk);
            polls++;
        end
        if (polls >= POLL_LIMIT)
            `uvm_error("DRV", "timed out waiting for DONE in drive_normal_xfer")

        reg_write(A_STATUS, 16'h0002);  // clear DONE write-1-to-clear
    endtask


    // TC02 - starts a normal transfer then cuts SS_N mid transfer

    task drive_ss_abort(spi_seq_item item);
        reg_write(A_TXDATA, {8'h00, item.tx_data});
        reg_write(A_CTRL, {item.clk_div, 7'h00, 1'b1});

        
        vif.do_ss_abort(item.abort_after_bits); // interface handle forcing SS_N high early


        
        repeat (10) @(posedge vif.clk); // extra cycles to settle back to IDLE
    endtask


    // TC03 BIST test case

    task drive_bist_run(spi_seq_item item, bit inject_fault);
        bit [7:0]  golden;
        bit [15:0] status;
        int polls;

        golden = compute_golden_sig(item.bist_mode);
        if (item.corrupt_sig_exp)
            golden = golden ^ 8'hFF;   // deliberately wrong fault injection

        reg_write(A_SIGEXP, {8'h00, golden});

        
        // BIST_START, BIST_EN all together

        reg_write(A_CTRL, {item.clk_div, 1'b0, 2'b00, item.bist_mode, 1'b1, 1'b1, 1'b0});

        if (inject_fault)
            vif.do_fault_inject();   // real hardware fault in mid-run

        polls = 0;
        status = 0;
        while (!status[2] && !status[3] && polls < POLL_LIMIT) begin  // PASS or FAIL bit
            reg_read(A_STATUS, status);
            @(posedge vif.clk);
            polls++;
        end
        if (polls >= POLL_LIMIT)
            `uvm_error("DRV", "timed out waiting for BIST_PASS/BIST_FAIL")

        reg_write(A_STATUS, 16'h000E);  // clear sticky bits
    endtask

endclass

`endif

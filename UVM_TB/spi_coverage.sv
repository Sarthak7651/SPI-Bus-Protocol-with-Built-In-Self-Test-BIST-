// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef SPI_COVERAGE_SV
`define SPI_COVERAGE_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "spi_seq_item.sv"

class spi_coverage extends uvm_subscriber #(spi_seq_item);
    `uvm_component_utils(spi_coverage)

    
    covergroup cg_spi_transactions with function sample(spi_seq_item t);

        //hit all tranfer kind

        cp_kind: coverpoint t.kind;

        //hit all bist mode

        cp_bist_mode: coverpoint t.bist_mode
            iff (t.kind inside {BIST_RUN, BIST_FAULT_INJECT}) 
        {
            bins loopback = {BIST_MODE_LOOPBACK};
            bins walk1    = {BIST_MODE_WALK1};
            bins prbs      = {BIST_MODE_PRBS};
        }

        // BIST actually PASS at least once

        cp_bist_pass_seen: coverpoint t.observed_bist_pass
            iff (t.kind inside {BIST_RUN, BIST_FAULT_INJECT}) {
            bins seen_pass = {1};
        }

        //BIST actually FAIL at least once
        cp_bist_fail_seen: coverpoint t.observed_bist_fail
            iff (t.kind inside {BIST_RUN, BIST_FAULT_INJECT}) {
            bins seen_fail = {1};
        }

        // all edge values hit atleast once 

        cp_data_value: coverpoint t.tx_data
            iff (t.kind == NORMAL_XFER) {
            bins all_zero = {8'h00};
            bins all_one  = {8'hFF};
            bins alt_55   = {8'h55};
            bins alt_AA   = {8'hAA};
            bins others   = default;
        }

        // SS_N abort mid tranfer at different points

        cp_abort_timing: coverpoint t.abort_after_bits
            iff (t.kind == SS_ABORT_XFER) {
            bins early = {[1:2]};
            bins mid   = {[3:5]};
            bins late  = {[6:7]};
        }

    endgroup

    function new(string name = "spi_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_spi_transactions = new();
    endfunction

    
    function void write(spi_seq_item t);
        cg_spi_transactions.sample(t);
    endfunction

    //scoreboard's report_phase
    
    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("overall functional coverage = %0.2f%%",
                                     cg_spi_transactions.get_coverage()), UVM_LOW)
    endfunction

endclass

`endif

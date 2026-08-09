// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef SPI_SCOREBOARD_SV
`define SPI_SCOREBOARD_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "spi_seq_item.sv"

class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)


    uvm_analysis_imp #(spi_seq_item, spi_scoreboard) imp;

    int pass_cnt;
    int fail_cnt;

    function new(string name = "spi_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        imp = new("imp", this);
        pass_cnt = 0;
        fail_cnt = 0;
    endfunction


   
    //golden signature calculation

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
            sig = {sig[6:0], sig[7]} ^ pattern;
        end
        return sig;
    endfunction


    // ap.write

    function void write(spi_seq_item item);
        case (item.kind)
            NORMAL_XFER: check_normal_xfer(item);
            BIST_RUN:    check_bist_run(item);
            default: `uvm_warning("SCB", $sformatf("scoreboard doesn't know how to check kind=%s yet",item.kind.name()))
        endcase
    endfunction

    // normal transfer check 

    function void check_normal_xfer(spi_seq_item item);
        if (item.observed_rx_data === item.tx_data) begin
            `uvm_info("SCB", $sformatf("PASS - normal xfer: sent 0x%0h, got 0x%0h back",item.tx_data, item.observed_rx_data), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error("SCB", $sformatf("FAIL - normal xfer: sent 0x%0h, but got 0x%0h back", item.tx_data, item.observed_rx_data))
            fail_cnt++;
        end
    endfunction

    // BIST mode checking 

    function void check_bist_run(spi_seq_item item);
        bit [7:0] golden;
        bit       expected_pass;

        golden = compute_golden_sig(item.bist_mode);

        
        expected_pass = (golden == item.bist_sig_exp);

        // check 1 signature checking

        if (item.observed_bist_sig_act !== golden) begin
            `uvm_error("SCB", $sformatf("FAIL - BIST mode=%0d signature wrong: DUT computed 0x%0h, should be 0x%0h",
                item.bist_mode, item.observed_bist_sig_act, golden))
            fail_cnt++;
            return;   // no point checking pass/fail decision if the signature itself is already wrong
        end

        // check 2 DUT checking

        if (expected_pass && item.observed_bist_pass) begin
            `uvm_info("SCB", $sformatf("PASS - BIST mode=%0d correctly reported PASS", item.bist_mode), UVM_LOW)
            pass_cnt++;
        end else if (!expected_pass && item.observed_bist_fail) begin
            `uvm_info("SCB", $sformatf("PASS - BIST mode=%0d correctly reported FAIL (as expected)", item.bist_mode), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error("SCB", $sformatf(
                "FAIL - BIST mode=%0d wrong verdict: expected_pass=%0b but saw pass=%0b fail=%0b",
                item.bist_mode, expected_pass, item.observed_bist_pass, item.observed_bist_fail))
            fail_cnt++;
        end
    endfunction


    // report_phase

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf("===================================="), UVM_LOW)
        `uvm_info("SCB", $sformatf("FINAL RESULT: %0d passed, %0d failed", pass_cnt, fail_cnt), UVM_LOW)
        `uvm_info("SCB", $sformatf("===================================="), UVM_LOW)
        if (fail_cnt == 0)
            `uvm_info("SCB", "ALL CHECKS PASSED", UVM_LOW)
        else
            `uvm_error("SCB", $sformatf("%0d CHECK(S) FAILED - see log above", fail_cnt))
    endfunction

endclass

`endif

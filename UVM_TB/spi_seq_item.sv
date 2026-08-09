// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef SPI_SEQ_ITEM_SV
`define SPI_SEQ_ITEM_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

// only keeping the kinds we actually use now
typedef enum {
    NORMAL_XFER,          // normal transfer
    SS_ABORT_XFER,         // abort mid transfer
    BIST_RUN,               // run a normal BIST test
    BIST_FAULT_INJECT        // run BIST but break something on purpose
} spi_txn_kind_e;


typedef enum bit [1:0] {
    BIST_MODE_LOOPBACK = 2'b00,   // fixed pattern
    BIST_MODE_WALK1    = 2'b01,   // walks a single 1 bit
    BIST_MODE_PRBS      = 2'b10   // random looking pattern
} bist_mode_e;

//sequence item class

class spi_seq_item extends uvm_sequence_item;
    rand spi_txn_kind_e kind;     // randomize once, tranfer kind

    rand bit [7:0] tx_data;       // normal tranfer data
    rand bit [7:0] clk_div;       // clock devision


    rand bist_mode_e bist_mode;         // bist modes
    rand bit         corrupt_sig_exp;    // 1 for deleberately fault injection


    rand int unsigned abort_after_bits;   // abort transfer after N bits

    bit [7:0] observed_rx_data;
    bit       observed_done;
    bit       observed_bist_pass;
    bit       observed_bist_fail;
    bit [3:0] observed_err_code;
    bit [7:0] observed_bist_sig_act;
    bit [7:0] bist_sig_exp;



    constraint c_clk_div_legal {
        clk_div inside {[1:16]};
    }


    constraint c_abort_bits_legal {
        abort_after_bits inside {[1:7]};
    }


    constraint c_kind_distribution {
        kind dist {
            NORMAL_XFER            := 40,
            SS_ABORT_XFER           := 10,
            BIST_RUN                := 20,
            BIST_FAULT_INJECT        := 8
        };
    }


    `uvm_object_utils_begin(spi_seq_item)
        `uvm_field_enum(spi_txn_kind_e, kind,        UVM_ALL_ON)
        `uvm_field_int(tx_data,                       UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(clk_div,                       UVM_ALL_ON | UVM_DEC)
        `uvm_field_enum(bist_mode_e, bist_mode,       UVM_ALL_ON)
        `uvm_field_int(corrupt_sig_exp,               UVM_ALL_ON)
        `uvm_field_int(abort_after_bits,              UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(observed_rx_data,              UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(observed_done,                 UVM_ALL_ON)
        `uvm_field_int(observed_bist_pass,            UVM_ALL_ON)
        `uvm_field_int(observed_bist_fail,            UVM_ALL_ON)
        `uvm_field_int(observed_err_code,             UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(observed_bist_sig_act,          UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    // new function

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction


    function string convert2string();
        string s;
        s = $sformatf("kind=%s", kind.name());

        if (kind == NORMAL_XFER || kind == SS_ABORT_XFER)
            s = {s, $sformatf(" tx_data=0x%0h clk_div=%0d", tx_data, clk_div)};

        if (kind == BIST_RUN || kind == BIST_FAULT_INJECT)
            s = {s, $sformatf(" bist_mode=%s corrupt_exp=%0b",
                                bist_mode.name(), corrupt_sig_exp)};

        if (kind == SS_ABORT_XFER)
            s = {s, $sformatf(" abort_after_bits=%0d", abort_after_bits)};

        return s;
    endfunction

endclass

`endif

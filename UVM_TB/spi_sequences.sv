// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef SPI_SEQUENCES_SV
`define SPI_SEQUENCES_SV


import uvm_pkg::*;
`include "uvm_macros.svh"
`include "spi_seq_item.sv"




// base class extends uvm_sequence

class spi_base_seq extends uvm_sequence #(spi_seq_item);
    `uvm_object_utils(spi_base_seq)

    function new(string name = "spi_base_seq");
        super.new(name);
    endfunction
endclass


// TC01 - normal transfer

class seq_tc01_basic_xfer extends spi_base_seq;
    `uvm_object_utils(seq_tc01_basic_xfer)

    function new(string name = "seq_tc01_basic_xfer");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        item = spi_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { kind == NORMAL_XFER; })
            `uvm_error("SEQ", "randomize failed in seq_tc01_basic_xfer")
        finish_item(item);
    endtask
endclass


// TC02 ss abort in the mid transfer

class seq_tc02_ss_abort extends spi_base_seq;
    `uvm_object_utils(seq_tc02_ss_abort)

    function new(string name = "seq_tc02_ss_abort");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        item = spi_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { kind == SS_ABORT_XFER; })
            `uvm_error("SEQ", "randomize failed in seq_tc02_ss_abort")
        finish_item(item);
    endtask
endclass


// TC03 edge data tranfer 

class seq_tc03_edge_data extends spi_base_seq;
    `uvm_object_utils(seq_tc03_edge_data)

    function new(string name = "seq_tc03_edge_data");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        bit [7:0] edge_values[4] = '{8'h00, 8'hFF, 8'h55, 8'hAA};

        foreach (edge_values[i]) begin
            item = spi_seq_item::type_id::create($sformatf("item_edge%0d", i));
            start_item(item);
            if (!item.randomize() with { kind == NORMAL_XFER; tx_data == edge_values[i]; })
                `uvm_error("SEQ", "randomize failed in seq_tc03_edge_data")
            finish_item(item);
        end
    endtask
endclass



// TC04 BIST Fixed pattern tranfer 

class seq_tc04_bist_mode0 extends spi_base_seq;
    `uvm_object_utils(seq_tc04_bist_mode0)

    function new(string name = "seq_tc04_bist_mode0");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        item = spi_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
                kind == BIST_RUN;
                bist_mode == BIST_MODE_LOOPBACK;
                corrupt_sig_exp == 0;   // healthy run must PASS
            })
            `uvm_error("SEQ", "randomize failed in seq_tc04_bist_mode0")
        finish_item(item);
    endtask
endclass

// TC05  BIST walking-1s 

class seq_tc05_bist_mode1 extends spi_base_seq;
    `uvm_object_utils(seq_tc05_bist_mode1)

    function new(string name = "seq_tc05_bist_mode1");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        item = spi_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
                kind == BIST_RUN;
                bist_mode == BIST_MODE_WALK1;
                corrupt_sig_exp == 0;
            })
            `uvm_error("SEQ", "randomize failed in seq_tc05_bist_mode1")
        finish_item(item);
    endtask
endclass


//TC06 BIST pseudo-random (LFSR) mode
class seq_tc06_bist_mode2 extends spi_base_seq;
    `uvm_object_utils(seq_tc06_bist_mode2)

    function new(string name = "seq_tc06_bist_mode2");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        item = spi_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
                kind == BIST_RUN;
                bist_mode == BIST_MODE_PRBS;
                corrupt_sig_exp == 0;
            })
            `uvm_error("SEQ", "randomize failed in seq_tc06_bist_mode2")
        finish_item(item);
    endtask
endclass


// TC07  BIST run with an injected fault verifying BIST correctness

class seq_tc07_bist_fault_inject extends spi_base_seq;
    `uvm_object_utils(seq_tc07_bist_fault_inject)

    function new(string name = "seq_tc07_bist_fault_inject");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        item = spi_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
                kind == BIST_FAULT_INJECT;
                corrupt_sig_exp == 1;   // force wrong expected value
            })
            `uvm_error("SEQ", "randomize failed in seq_tc07_bist_fault_inject")
        finish_item(item);
    endtask
endclass


//TC09 constrained-random regression accross all 

class seq_random_regression extends spi_base_seq;
    `uvm_object_utils(seq_random_regression)

    int num_items = 50;

    function new(string name = "seq_random_regression");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        for (int i = 0; i < num_items; i++) begin
            item = spi_seq_item::type_id::create($sformatf("item_%0d", i));
            start_item(item);
            // no "with" constraint here - let the item's own
            // c_kind_mix constraint pick kind using the weights
            if (!item.randomize())
                `uvm_error("SEQ", "randomize failed in seq_random_regression")
            finish_item(item);
        end
    endtask
endclass


// master sequence, runs every TC one by one so we get the
// full coverage number in one single run. also throws in a
// few extra abort items with different abort_after_bits so
// early/mid/late abort timing bins all get hit for sure,
// TC02 alone only sends one random item so it might miss some

class seq_master_regression extends spi_base_seq;
    `uvm_object_utils(seq_master_regression)

    function new(string name = "seq_master_regression");
        super.new(name);
    endfunction

    task body();
        seq_tc01_basic_xfer        t1;
        seq_tc02_ss_abort          t2;
        seq_tc03_edge_data         t3;
        seq_tc04_bist_mode0        t4;
        seq_tc05_bist_mode1        t5;
        seq_tc06_bist_mode2        t6;
        seq_tc07_bist_fault_inject t7;
        seq_random_regression      t8;
        spi_seq_item item;
        int abort_pts[3] = '{1, 4, 7};   // early, mid, late

        t1 = seq_tc01_basic_xfer::type_id::create("t1");
        t1.start(m_sequencer);

        t2 = seq_tc02_ss_abort::type_id::create("t2");
        t2.start(m_sequencer);

        t3 = seq_tc03_edge_data::type_id::create("t3");
        t3.start(m_sequencer);

        t4 = seq_tc04_bist_mode0::type_id::create("t4");
        t4.start(m_sequencer);

        t5 = seq_tc05_bist_mode1::type_id::create("t5");
        t5.start(m_sequencer);

        t6 = seq_tc06_bist_mode2::type_id::create("t6");
        t6.start(m_sequencer);

        t7 = seq_tc07_bist_fault_inject::type_id::create("t7");
        t7.start(m_sequencer);

        // extra abort sweep just for coverage, makes sure all
        // 3 abort timing bins get hit every single run
        foreach (abort_pts[i]) begin
            item = spi_seq_item::type_id::create($sformatf("abort_extra_%0d", i));
            start_item(item);
            if (!item.randomize() with {
                    kind             == SS_ABORT_XFER;
                    abort_after_bits == abort_pts[i];
                })
                `uvm_error("SEQ", "randomize failed in seq_master_regression abort sweep")
            finish_item(item);
        end

        t8 = seq_random_regression::type_id::create("t8");
        t8.start(m_sequencer);
    endtask
endclass

`endif

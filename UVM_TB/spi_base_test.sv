// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef SPI_BASE_TEST_SV
`define SPI_BASE_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "spi_env.sv"
`include "spi_sequences.sv"



//base class

class spi_base_test extends uvm_test;
    `uvm_component_utils(spi_base_test)

    spi_env env;

    function new(string name = "spi_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = spi_env::type_id::create("env", this);
    endfunction

    // raise_objection/drop_objection

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        run_test_sequence(phase);
        phase.drop_objection(this);
    endtask

    virtual task run_test_sequence(uvm_phase phase);
        `uvm_warning("TEST", "spi_base_test run directly - this shouldn't happen normally")
    endtask

endclass


// TC01 - basic tranfer

class test_tc01_basic_xfer extends spi_base_test;
    `uvm_component_utils(test_tc01_basic_xfer)
    function new(string name = "test_tc01_basic_xfer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        seq_tc01_basic_xfer seq;
        seq = seq_tc01_basic_xfer::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask
endclass



// TC02 - sub-state abort 

class test_tc02_ss_abort extends spi_base_test;
    `uvm_component_utils(test_tc02_ss_abort)
    function new(string name = "test_tc02_ss_abort", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        seq_tc02_ss_abort seq;
        seq = seq_tc02_ss_abort::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask
endclass



// TC03 - edge data 

class test_tc03_edge_data extends spi_base_test;
    `uvm_component_utils(test_tc03_edge_data)
    function new(string name = "test_tc03_edge_data", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        seq_tc03_edge_data seq;
        seq = seq_tc03_edge_data::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask
endclass



// TC04 - BIST fixed-pattern mode

class test_tc04_bist_mode0 extends spi_base_test;
    `uvm_component_utils(test_tc04_bist_mode0)
    function new(string name = "test_tc04_bist_mode0", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        seq_tc04_bist_mode0 seq;
        seq = seq_tc04_bist_mode0::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask
endclass



// TC05 - BIST walking-1s mode

class test_tc05_bist_mode1 extends spi_base_test;
    `uvm_component_utils(test_tc05_bist_mode1)
    function new(string name = "test_tc05_bist_mode1", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        seq_tc05_bist_mode1 seq;
        seq = seq_tc05_bist_mode1::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask
endclass



// TC06 - BIST pseudo-random (LFSR) mode

class test_tc06_bist_mode2 extends spi_base_test;
    `uvm_component_utils(test_tc06_bist_mode2)
    function new(string name = "test_tc06_bist_mode2", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        seq_tc06_bist_mode2 seq;
        seq = seq_tc06_bist_mode2::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask
endclass



// TC07 - BIST run with an injected fault

class test_tc07_bist_fault_inject extends spi_base_test;
    `uvm_component_utils(test_tc07_bist_fault_inject)
    function new(string name = "test_tc07_bist_fault_inject", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        seq_tc07_bist_fault_inject seq;
        seq = seq_tc07_bist_fault_inject::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask
endclass


// constrained-random regression 

class test_random_regression extends spi_base_test;
    `uvm_component_utils(test_random_regression)
    function new(string name = "test_random_regression", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        seq_random_regression seq;
        seq = seq_random_regression::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask
endclass


// master test - runs TC01 to TC07 plus the abort sweep plus
// the random regression, all in one simulation. this is the
// one to run when we need to see the overall coverage number

class test_master_regression extends spi_base_test;
    `uvm_component_utils(test_master_regression)
    function new(string name = "test_master_regression", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        seq_master_regression seq;
        seq = seq_master_regression::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask
endclass

`endif

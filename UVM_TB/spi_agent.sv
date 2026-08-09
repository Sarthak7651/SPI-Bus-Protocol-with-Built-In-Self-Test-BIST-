// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef SPI_AGENT_SV
`define SPI_AGENT_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "spi_sequencer.sv"
`include "spi_driver.sv"
`include "spi_monitor.sv"

class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)

    spi_sequencer sequencer;
    spi_driver    driver;
    spi_monitor   monitor;

//analysis port

    uvm_analysis_port #(spi_seq_item) ap;
    uvm_analysis_port #(spi_seq_item) req_ap;   // passthrough for driver.req_ap

    function new(string name = "spi_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        monitor = spi_monitor::type_id::create("monitor", this);

        if (is_active == UVM_ACTIVE) begin
            sequencer = spi_sequencer::type_id::create("sequencer", this);
            driver    = spi_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // connecting agent ap to the monitor ap
        ap = monitor.ap;

        if (is_active == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
            req_ap = driver.req_ap;   // connecting agent req_ap to driver req_ap
        end
    endfunction

endclass

`endif

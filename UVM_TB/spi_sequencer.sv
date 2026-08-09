// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef SPI_SEQUENCER_SV
`define SPI_SEQUENCER_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "spi_seq_item.sv"

class spi_sequencer extends uvm_sequencer #(spi_seq_item);
    `uvm_component_utils(spi_sequencer)

    function new(string name = "spi_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass

`endif

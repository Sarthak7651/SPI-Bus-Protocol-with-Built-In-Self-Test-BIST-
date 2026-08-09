// include guard, stops this file getting compiled twice
// if it ends up listed in the fileset AND `include-d somewhere
`ifndef SPI_IF_SV
`define SPI_IF_SV

interface spi_if(input bit clk);

    logic rst_n;

    //registers bus

    logic        wr_en;
    logic [3:0]  wr_addr;
    logic [15:0] wr_data;
    logic [3:0]  rd_addr;
    logic [15:0] rd_data;

    //external SPI pins

    logic spi_sclk;
    logic spi_mosi;
    logic spi_ss_n;
    logic spi_miso;

    //debug pulses
    
    logic bist_pass_pulse;
    logic bist_fail_pulse;

    //monitor signals

    logic [7:0] mon_rx_data;
    logic       mon_done;
    logic       mon_bist_pass;
    logic       mon_bist_fail;
    logic [3:0] mon_err_code;
    logic [7:0] mon_bist_sig_act;

    // is bist running right now, need this so monitor does not
    // think a bist internal byte is a normal transfer
    logic mon_bist_busy;

    //request/ack handshake

    logic       ss_abort_req;
    logic [2:0] ss_abort_bits;
    logic       ss_abort_done;

    logic       fault_inject_req;
    logic       fault_inject_done;


    //reset signal

    task do_reset_pulse(input int cycles);
        repeat (cycles) @(posedge clk);
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
    endtask

    //ss abort 

    task do_ss_abort(input int bits);
        ss_abort_bits = bits;
        ss_abort_req  = 1;
        @(posedge ss_abort_done);
        ss_abort_req  = 0;
        @(posedge clk);
    endtask

    //fault injection 

    task do_fault_inject();
        fault_inject_req = 1;
        @(posedge fault_inject_done);
        fault_inject_req = 0;
        @(posedge clk);
    endtask

endinterface

`endif

`timescale 1ns / 1ps

module spi_bist_top
#(parameter DATA_WIDTH =8,
  parameter ADDR_WIDTH =4,
  parameter WORD_COUNT =8,
  parameter TIMEOUT_VAL = 512,
  parameter [7:0] LFSR_SEED_VAL = 8'h01)
(//system
  input wire clk,
  input wire rst_n,
 // host register write port
  input wire wr_en,
  input wire [ADDR_WIDTH-1:0] wr_addr,
  input wire [15:0] wr_data,
 // host register read port
 input wire [ADDR_WIDTH-1:0] rd_addr,
 output wire [15:0] rd_data,
 //external SPI Pins
 output wire spi_sclk,
 output wire spi_mosi,
 output wire spi_ss_n,
 input wire spi_miso,
 //debug
 output wire bist_pass_pulse,
 output wire bist_fail_pulse  
  );
  
//register file <-> spi master wires
wire cpol_w;
wire cpha_w;
wire [7:0] clk_div_w;
wire [DATA_WIDTH-1:0] tx_data_reg_w;
wire spi_en_reg_w;

wire [DATA_WIDTH-1:0] rx_data_m_w;
wire busy_w;
wire done_w;

//register file <-> bist controller wires
wire bist_en_w;
wire bist_start_reg_w;
wire [1:0] bist_mode_w;
wire [DATA_WIDTH-1:0] bist_sig_exp_w;

wire bist_pass_w;
wire bist_fail_w;
wire bist_busy_w;
wire [3:0] err_code_w;

wire bist_start_qualified_w = bist_start_reg_w & bist_en_w;

//bist controller <-> spi master wires
wire bist_spi_en_w;
wire [DATA_WIDTH-1:0] bist_tx_w;
wire loopback_en_w;

wire spi_en_to_master_w = loopback_en_w ? bist_spi_en_w : spi_en_reg_w;
wire [DATA_WIDTH-1:0] tx_data_to_master_w = loopback_en_w ? bist_tx_w : tx_data_reg_w;

//bist controller <-> LFSR wires
wire lfsr_seed_load_w;
wire lfsr_en_w;
wire [DATA_WIDTH-1:0] lfsr_data_w;

//bist controller <-> misr wires
wire misr_en_w;
wire misr_rst_w;
wire [DATA_WIDTH-1:0] misr_sig_w;

//spi master <-> loopback mux
wire master_sclk_w;
wire master_mosi_w;
wire master_ss_n_w;
wire master_miso_w;

//loopback MUX <-> internal spi slave wires
wire slave_sclk_w;
wire slave_mosi_w;
wire slave_ss_n_w;
wire slave_miso_w;
wire [DATA_WIDTH-1:0] slave_rx_data_w;
wire slave_rx_done_w;

// debug pulse pass-through
assign bist_pass_pulse = bist_pass_w;
assign bist_fail_pulse = bist_fail_w;

//reg file instance
spi_regfile #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH)
) u_regfile (
    .clk             (clk),
    .rst_n           (rst_n),
 
    .wr_en           (wr_en),
    .wr_addr         (wr_addr),
    .wr_data         (wr_data),
    .rd_addr         (rd_addr),
    .rd_data         (rd_data),
 
    .spi_en_out      (spi_en_reg_w),
    .cpol            (cpol_w),
    .cpha            (cpha_w),
    .clk_div         (clk_div_w),
    .tx_data         (tx_data_reg_w),
 
    .rx_data_in      (rx_data_m_w),
    .busy_in         (busy_w),
    .done_in         (done_w),
 
    .bist_en         (bist_en_w),
    .bist_start_out  (bist_start_reg_w),
    .bist_mode       (bist_mode_w),
    .bist_sig_exp    (bist_sig_exp_w),
 
    .bist_pass_in    (bist_pass_w),
    .bist_fail_in    (bist_fail_w),
    .bist_sig_act_in (misr_sig_w),
    .err_code_in     (err_code_w)
);
 
//spi master instance
spi_master #(
    .DATA_WIDTH (DATA_WIDTH)
) u_master (
    .clk      (clk),
    .rst_n    (rst_n),
 
    .spi_en   (spi_en_to_master_w),   // Decision 1: muxed source
    .cpol     (cpol_w),
    .cpha     (cpha_w),
    .clk_div  (clk_div_w),
 
    .tx_data  (tx_data_to_master_w),  // Decision 1: muxed source
    .rx_data  (rx_data_m_w),
 
    .busy     (busy_w),
    .done     (done_w),
 
    .sclk     (master_sclk_w),
    .mosi     (master_mosi_w),
    .ss_n     (master_ss_n_w),
    .miso     (master_miso_w)
);

//loopback mux
loopback_mux u_loopback_mux (
    .loopback_en (loopback_en_w),
 
    .m_sclk      (master_sclk_w),
    .m_mosi      (master_mosi_w),
    .m_ss_n      (master_ss_n_w),
    .m_miso      (master_miso_w),
 
    .ext_sclk    (spi_sclk),
    .ext_mosi    (spi_mosi),
    .ext_ss_n    (spi_ss_n),
    .ext_miso    (spi_miso),
 
    .slv_sclk    (slave_sclk_w),
    .slv_mosi    (slave_mosi_w),
    .slv_ss_n    (slave_ss_n_w),
    .slv_miso    (slave_miso_w)
);

//internal spi slave(bist loopback target)
spi_slave #(
    .DATA_WIDTH (DATA_WIDTH)
) u_slave (
    .clk      (clk),
    .rst_n    (rst_n),
 
    .cpol     (cpol_w),
    .cpha     (cpha_w),
 
    .sclk_in  (slave_sclk_w),
    .mosi     (slave_mosi_w),
    .miso     (slave_miso_w),
    .ss_n_in  (slave_ss_n_w),
 
    .tx_data  (bist_tx_w),            // Decision 2: zero-latency echo
    .rx_data  (slave_rx_data_w),
    .rx_done  (slave_rx_done_w)
);

//bist controller
bist_ctrl #(
    .DATA_WIDTH  (DATA_WIDTH),
    .WORD_COUNT  (WORD_COUNT),
    .TIMEOUT_VAL (TIMEOUT_VAL)
) u_bist_ctrl (
    .clk            (clk),
    .rst_n          (rst_n),
 
    .bist_start     (bist_start_qualified_w),  // Decision 3: AND-gated
    .bist_mode      (bist_mode_w),
    .bist_sig_exp   (bist_sig_exp_w),
 
    .bist_pass      (bist_pass_w),
    .bist_fail      (bist_fail_w),
    .bist_busy      (bist_busy_w),
    .err_code       (err_code_w),
 
    .spi_en         (bist_spi_en_w),
    .spi_done       (done_w),
    .rx_data        (rx_data_m_w),
    .bist_tx        (bist_tx_w),
 
    .lfsr_seed_load (lfsr_seed_load_w),
    .lfsr_en        (lfsr_en_w),
    .lfsr_data      (lfsr_data_w),
 
    .misr_en        (misr_en_w),
    .misr_rst       (misr_rst_w),
    .misr_sig       (misr_sig_w),
 
    .loopback_en    (loopback_en_w)
);

//lfsr pattern generator
 lfsr #(
    .DATA_WIDTH   (DATA_WIDTH),
    .DEFAULT_SEED (LFSR_SEED_VAL)
) u_lfsr (
    .clk       (clk),
    .rst_n     (rst_n),
 
    .seed_load (lfsr_seed_load_w),
    .seed_in   (LFSR_SEED_VAL),        // Decision 4: fixed golden-matching seed
 
    .en        (lfsr_en_w),
    .lfsr_data (lfsr_data_w)
);

//MISR SIG Analyzer
misr #(
    .DATA_WIDTH (DATA_WIDTH)
) u_misr (
    .clk      (clk),
    .rst_n    (rst_n),
 
    .misr_rst (misr_rst_w),
    .misr_en  (misr_en_w),
    .data_in  (rx_data_m_w),           // Master's received byte (loopback)
 
    .sig_out  (misr_sig_w)
);
  
endmodule

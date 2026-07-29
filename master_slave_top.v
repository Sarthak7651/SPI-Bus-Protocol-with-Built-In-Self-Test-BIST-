`timescale 1ns / 1ps

module master_slave_top #(
    parameter DATA_WIDTH = 8
)(
    // ?? System Signals ??????????????????????????????????????
    input  wire                    clk,             // System clock
    input  wire                    rst_n,           // Active-low reset

    // ?? Configuration Interface ?????????????????????????????
    input  wire                    cpol,            // Clock polarity
    input  wire                    cpha,            // Clock phase
    input  wire [7:0]              clk_div,         // Clock divider for master SCLK

    // ?? Master Interface ????????????????????????????????????
    input  wire                    master_spi_en,   // Start transfer pulse
    input  wire [DATA_WIDTH-1:0]   master_tx_data,  // Data to transmit
    output wire [DATA_WIDTH-1:0]   master_rx_data,  // Data received from slave
    output wire                    master_busy,     // Master transfer busy flag
    output wire                    master_done,     // Master transfer done pulse

    // ?? Slave Interface ?????????????????????????????????????
    input  wire [DATA_WIDTH-1:0]   slave_tx_data,   // Data to send back to master
    output wire [DATA_WIDTH-1:0]   slave_rx_data,   // Data received from master
    output wire                    slave_rx_done,   // Slave byte received pulse

    // ?? SPI Bus Monitor Output Pins (Optional / Debug) ??????
    output wire                    spi_sclk,        // Serial Clock
    output wire                    spi_mosi,        // Master Out Slave In
    output wire                    spi_miso,        // Master In Slave Out
    output wire                    spi_ss_n         // Slave Select (Active Low)
);

    // ========================================================
    //  Internal Bus Wires
    // ========================================================
    wire sclk_bus;
    wire mosi_bus;
    wire miso_bus;
    wire ss_n_bus;

    // Direct internal SPI bus lines to top-level debug outputs
    assign spi_sclk = sclk_bus;
    assign spi_mosi = mosi_bus;
    assign spi_miso = miso_bus;
    assign spi_ss_n = ss_n_bus;

    // ========================================================
    //  Module Instantiations
    // ========================================================

    // 1. SPI Master Instance
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_spi_master (
        // System
        .clk     (clk),
        .rst_n   (rst_n),
        // Configuration & Control
        .spi_en  (master_spi_en),
        .cpol    (cpol),
        .cpha    (cpha),
        .clk_div (clk_div),
        // Data & Status
        .tx_data (master_tx_data),
        .rx_data (master_rx_data),
        .busy    (master_busy),
        .done    (master_done),
        // SPI Bus Pins
        .sclk    (sclk_bus),
        .mosi    (mosi_bus),
        .ss_n    (ss_n_bus),
        .miso    (miso_bus)
    );

    // 2. SPI Slave Instance
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_spi_slave (
        // System
        .clk     (clk),
        .rst_n   (rst_n),
        // Configuration
        .cpol    (cpol),
        .cpha    (cpha),
        // SPI Bus Pins
        .sclk_in (sclk_bus),
        .mosi    (mosi_bus),
        .miso    (miso_bus),
        .ss_n_in (ss_n_bus),
        // Data & Status
        .tx_data (slave_tx_data),
        .rx_data (slave_rx_data),
        .rx_done (slave_rx_done)
    );

endmodule
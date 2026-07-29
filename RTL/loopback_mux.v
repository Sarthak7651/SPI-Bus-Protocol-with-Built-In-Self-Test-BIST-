`timescale 1ns / 1ps

module loopback_mux(
//select
input wire loopback_en,
//spi master side(bidirectional pair)
input wire m_sclk,
input wire m_mosi,
input wire m_ss_n,
output reg m_miso,
//external pin
output reg ext_sclk,
output reg ext_mosi,
output reg ext_ss_n,
input wire ext_miso,
//internal BIST slave side
output reg slv_sclk,
output reg slv_mosi,
output reg slv_ss_n,
input wire slv_miso
);

localparam IDLE_SCLK = 1'b0;
localparam IDLE_MOSI = 1'b0;
localparam IDLE_SSN = 1'b1;

//combination routing
always @(*) begin
  if(loopback_en) begin
     slv_sclk = m_sclk;
     slv_mosi = m_mosi;
     slv_ss_n = m_ss_n;
     m_miso = slv_miso;
  
    ext_sclk = IDLE_SCLK;
    ext_mosi = IDLE_MOSI;
    ext_ss_n = IDLE_SSN;
    
 end else begin
    ext_sclk = m_sclk;
    ext_mosi = m_mosi;
    ext_ss_n = m_ss_n;
    m_miso = ext_miso;
    
    slv_sclk = IDLE_SCLK;
    slv_mosi = IDLE_MOSI;
    slv_ss_n = IDLE_SSN;
 end
end       
endmodule

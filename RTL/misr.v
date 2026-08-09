`timescale 1ns / 1ps
module misr
#(parameter DATA_WIDTH=8)
(//SYSTEM
 input wire clk,
 input wire rst_n,
 //control
 input wire misr_rst,//only reset MISR
 input wire misr_en,//enable or disbale MISR
 //data
 input wire [DATA_WIDTH-1:0] data_in,//this is recived SPI data
 //output 
 output wire [DATA_WIDTH-1:0] sig_out//this is current signature
);

//internal register
reg [DATA_WIDTH-1:0] sig_reg;//store the current signature
assign sig_out = sig_reg;

//ROTATE LEFT 1 WIRE
/*
  Rotate sig_reg left by 1 bit:
    MSB (bit DATA_WIDTH-1) wraps around to become the new LSB.
    Example (8-bit): sig_reg = 1010_0101
                      rotated = 0100_1011
*/
//rotate left by 1
wire [DATA_WIDTH-1:0] rotated = {sig_reg[DATA_WIDTH-2:0],sig_reg[DATA_WIDTH-1]};

//main logic
always @(posedge clk) begin
  if(!rst_n) begin
     sig_reg <= {DATA_WIDTH{1'b0}};
  end else if(misr_rst) begin
  sig_reg <= {DATA_WIDTH{1'b0}};
  end else if(misr_en) begin
  sig_reg <= rotated ^ data_in;
  end 
  //else: hold current value (no misr_rst, no misr_en)
end      
endmodule

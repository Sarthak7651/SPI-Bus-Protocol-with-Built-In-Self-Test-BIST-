`timescale 1ns / 1ps

module spi_master #(parameter DATA_WIDTH=8)
( //system
  input wire clk, //system clk
  input wire rst_n, //active low sync reset
  //control
  input wire spi_en, //pulse for 1 cycle to start a transfer
  input wire cpol, //clock polarity,unused
  input wire cpha, //clock phase,unused
  input wire [7:0] clk_div, //to establish connection bw clk and sclk,sclk freq=clk/(2*clk_div)
  //data
  /*Trasmit Data:- What it is: An 8-bit storage buffer.
  Its Job: When the CPU wants to send a byte (like 8'hA5), it writes it here. tx_data holds onto 
  this value for the entire duration of the SPI transaction. It does not shift; it just remembers
  what the CPU asked it to send.*/
  input wire [DATA_WIDTH-1:0] tx_data,//byte to transmit when spi_en=1
  
  /*received data:- What it is: An 8-bit storage buffer.
  Its Job: This holds the final, complete, 8-bit byte that was received from the Slave. It only updates
   after a full transaction is 100% complete. This ensures that if the CPU reads the register, it gets 
   a perfectly clean byte, not a half-assembled piece of garbage.*/
  output reg [DATA_WIDTH-1:0] rx_data,//rcvd byte
  //status
  output reg busy,//high while transfer in progress
  output reg done,//1 when transfer is completed
  //spi pins
  output reg sclk,//spi serial clk output
  output reg mosi,//master out slave in data line
  output reg ss_n,//slave select (active low) 
  input wire miso//master in slave out data line
);

localparam [1:0] S_IDLE = 2'b00,//wait for spi_en pulse
                 S_LOAD = 2'b01,//latch tx data,assert ss_n,pre-drive mosi(cpha=0)
                 S_SHIFT = 2'b10,//toggle sclk,shift mosi out,shift miso in
                 S_DONE = 2'b11;//pulse done flag,deassert ss_n,return to idle
                 
//INTERNAL REGISTER
reg [1:0] state;
reg [DATA_WIDTH-1:0] tx_shift;
reg [DATA_WIDTH-1:0] rx_shift;
reg [7:0] div_cnt;//clock divider down counter
reg [3:0] bit_cnt;//Number of bits captured

//clock sampling mode
//wire sample_on_pos = ~(cpol ^ cpha); //clock mode
localparam sample_on_pos = 1'b1; //mode0 always sample on rising edge
//SCLK edge detection (look ahead style)
//div_cnt limit is (clk_div-1)
wire sclk_toggle = (state == S_SHIFT) && (div_cnt == clk_div - 8'd1);
/*(Rising Edge): If the clock is about to flip (sclk_toggle == 1) AND it is currently LOW (~sclk),
 then it MUST be flipping from 0 to 1.*/
wire pos_edge = sclk_toggle && (~sclk); //0 -> 1
/*(Falling Edge): If the clock is about to flip (sclk_toggle == 1) AND it is currently HIGH (sclk),
 then it MUST be flipping from 1 to 0*/
wire neg_edge = sclk_toggle && (sclk); //1 -> 0

/*
wire sample_edge = sample_on_pos ? pos_edge : neg_edge;
wire shift_edge = sample_on_pos ? neg_edge : pos_edge;
*/

//mode 0 fixed maping
wire sample_edge = pos_edge;
wire shift_edge = neg_edge;

//clock divider and SCLK generator
always @(posedge clk) begin
if(!rst_n) begin
    div_cnt <= 8'b0;
    sclk    <= 1'b0;
    end else begin
    if (state == S_SHIFT) begin
        if (div_cnt == clk_div - 8'b1) begin
            div_cnt <= 8'b0;
            sclk <= ~sclk;
          end else begin
            div_cnt <= div_cnt + 8'b1;
          end
      end else begin
          div_cnt <= 8'b0;
          //sclk <= cpol;//idle level
          sclk <= 1'b0; //mode:0 always low(fixed)
      end
   end
end       

always @(posedge clk) begin
if(!rst_n) begin
   state  <= S_IDLE;
   tx_shift <= {DATA_WIDTH{1'b0}};
   rx_shift <= {DATA_WIDTH{1'b0}};
   rx_data  <= {DATA_WIDTH{1'b0}};
   bit_cnt  <= 4'b0;
   mosi     <= 1'b0;
   ss_n     <= 1'b1;//bcz active low signal
   busy     <= 1'b0;
   done     <= 1'b0;
end else begin
   
   done <= 1'b0; //done is always 0 unless pulsed in S_DONE
   
   case (state)
   
   S_IDLE: begin
           ss_n <= 1'b1;
           busy <= 1'b0;
           mosi <= 1'b0;
           if (spi_en)
           state <= S_LOAD;
           end
           
   S_LOAD: begin
           tx_shift <= tx_data;
           rx_shift <= {DATA_WIDTH{1'b0}};
           bit_cnt  <= 4'd0;
           ss_n     <= 1'b0;
           busy     <= 1'b1;
           
           /*if(!cpha)
           mosi <= tx_data[DATA_WIDTH-1];//pre drive MSB for mode 0/2
           */
           mosi <= tx_data[DATA_WIDTH-1]; //Mode0:always pre-drive MSB
           state <= S_SHIFT;
           end
           
    S_SHIFT: begin
          //sample MISO
          if(sample_edge) begin
            if (bit_cnt == DATA_WIDTH-1) begin
            rx_data <= {rx_shift[DATA_WIDTH-2:0],miso};
            ss_n <= 1'b1;
            state <= S_DONE;
          end else begin
            rx_shift <= {rx_shift[DATA_WIDTH-2:0],miso};
            bit_cnt <= bit_cnt + 4'd1;
          end
          end 
          
          //shift MOSI
          if (shift_edge) begin
             /*if(!cpha) begin
             mosi <= tx_shift[DATA_WIDTH-2];
             end 
             else begin
             mosi <= tx_shift[DATA_WIDTH-1];
             end*/
             mosi <= tx_shift[DATA_WIDTH-2];
             tx_shift <= {tx_shift[DATA_WIDTH-2:0],1'b0};
             end
        end
 
 S_DONE: begin
        ss_n <= 1'b1;
        busy <= 1'b0;
        done <= 1'b1;
        state <= S_IDLE;
        end
        default: state <= S_IDLE;
        
      endcase
   end
end               
endmodule

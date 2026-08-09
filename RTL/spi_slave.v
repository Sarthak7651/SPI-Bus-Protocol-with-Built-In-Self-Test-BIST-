`timescale 1ns / 1ps

module spi_slave #(parameter DATA_WIDTH = 8)(
//system
input wire clk,//system clk
input wire rst_n,//synch rst
//mode config
input wire cpol,//unused
input wire cpha,//unused
//spi pins
input wire sclk_in,//sclk from master
input wire mosi,//data froom master
output reg miso,//data to slave
input wire ss_n_in,//slave select from master
//data interface
input wire [DATA_WIDTH-1:0] tx_data,//byte send from master
output reg [DATA_WIDTH-1:0] rx_data,//byte rcvd from master
output reg rx_done //1 cycle pulse when a complete byte is rvcd
);

localparam [1:0] S_IDLE = 2'd0,
                 S_ACTIVE = 2'd1,
                 S_DONE = 2'd2;

//internal register                 
reg [1:0]            state;
reg [DATA_WIDTH-1:0] tx_shift;//msb first  
reg [DATA_WIDTH-1:0] rx_shift;   
reg [3:0]            bit_cnt;//0 to data_width-1 

//3 FF SYNC for SCLK and SS_N
/*
  Why synchronize?
    SCLK and SS_N come from a different clock source (the master's
    SCLK divider) or from external pins.  Even on the same FPGA,
    SCLK is asynchronous to posedge clk at the slave's input.
    three flip-flops reduce the probability of metastability to an
    acceptable level.
*/
//SCLK synchronizer

reg sclk_d1,sclk_d2,sclk_d3;

always @(posedge clk) begin
    if(!rst_n) begin
        sclk_d1 <= 1'b0;
        sclk_d2 <= 1'b0;
        sclk_d3 <= 1'b0;
    end else begin
        sclk_d1 <= sclk_in; //stage1:metastability latch
        sclk_d2 <= sclk_d1; //stage2: stable synchromizer SCLK
        sclk_d3 <= sclk_d2; //stage3: one cycle behind d2 for edge detect   
   end
end

//ss_n Synchronizer
reg ssn_d1, ssn_d2, ssn_d3;
 
always @(posedge clk) begin
    if (!rst_n) begin
        ssn_d1 <= 1'b1;
        ssn_d2 <= 1'b1;
        ssn_d3 <= 1'b1;
    end else begin
        ssn_d1 <= ss_n_in;
        ssn_d2 <= ssn_d1;
        ssn_d3 <= ssn_d2;
    end
end      

//MOSI synchronizer
//1FF is sufficient
reg mosi_s;

always @(posedge clk) begin
     if (!rst_n) mosi_s <= 1'b0;
     else        mosi_s <= mosi;
end

//  SECTION 4 : Edge Detection (from synchronized signals)
wire sclk_rise = ( sclk_d2) & (~sclk_d3);
wire sclk_fall = (~sclk_d2) & ( sclk_d3);
wire ss_fall   = (~ssn_d2)  & ( ssn_d3);   // SS_N asserted  (1?0)
wire ss_rise   = ( ssn_d2)  & (~ssn_d3);   // SS_N deasserted(0?1)           


//clock mode

/*wire sample_on_pos = ~(cpol ^ cpha); 
wire sample_edge = sample_on_pos ? sclk_rise : sclk_fall;
wire shift_edge  = sample_on_pos ? sclk_fall  : sclk_rise;
*/

wire sample_edge = sclk_rise;
wire shift_edge = sclk_fall;

//main FSM
always @(posedge clk) begin
    if (!rst_n) begin
        state    <= S_IDLE;
        tx_shift <= {DATA_WIDTH{1'b0}};
        rx_shift <= {DATA_WIDTH{1'b0}};
        rx_data  <= {DATA_WIDTH{1'b0}};
        bit_cnt  <= 4'd0;
        miso     <= 1'b0;
        rx_done  <= 1'b0;
   end else begin    
       rx_done <= 1'b0;
   case (state)
      S_IDLE: begin
               miso <= 1'b0;
               if (ss_fall) begin
               tx_shift <= tx_data;
               rx_shift <= {DATA_WIDTH{1'b0}};
               bit_cnt  <= 4'd0;
               //if (!cpha)
               miso <= tx_data[DATA_WIDTH-1];  // Pre-drive MSB
               state <= S_ACTIVE;
               end
           end  
       
      S_ACTIVE: begin
           //capture MOSI on sampe edge
           if (sample_edge) begin
               if (bit_cnt == DATA_WIDTH - 1) begin
               // 8th bit -> latch full byte, done
               rx_data <= {rx_shift[DATA_WIDTH-2:0], mosi_s};
               state   <= S_DONE;
               end else begin
               rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi_s};
               bit_cnt  <= bit_cnt + 4'd1;
               end
            end
           //abort on SS_N high 
           else if (ss_rise) begin
           state <= S_IDLE;
           end
           //update MISO on shift edge
            if (shift_edge) begin
               /*if (!cpha)
               miso <= tx_shift[DATA_WIDTH-2]; // CPHA=0: next bit
               else*/
               miso <= tx_shift[DATA_WIDTH-2]; // mode 0: next bit
               tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
               end
           end
          
     S_DONE: begin
             rx_done <= 1'b1;
             state   <= S_IDLE;
             end
            default: state <= S_IDLE;
            endcase
         end
      end          
endmodule 

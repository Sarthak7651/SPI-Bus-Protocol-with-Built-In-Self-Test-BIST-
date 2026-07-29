`timescale 1ns / 1ps

module spi_regfile#(parameter DATA_WIDTH=8,
                    parameter ADDR_WIDTH=4)
(//system
 input wire clk,
 input wire rst_n,
 //wire port
 input wire wr_en,
 input wire [ADDR_WIDTH-1:0] wr_addr,
 input wire [15:0] wr_data,
 //Read port
 input wire[ADDR_WIDTH-1:0] rd_addr,
 output reg [15:0] rd_data,
 //to spi master
 output reg spi_en_out,
 output wire cpol,//reserved always 0
 output wire cpha,//reserved always 0
 output wire [7:0] clk_div,
 output wire [DATA_WIDTH-1:0] tx_data,
 //from spi master
 input wire [DATA_WIDTH-1:0] rx_data_in,
 input wire busy_in,
 input wire done_in,
 //to bist controller
 output wire bist_en,
 output reg bist_start_out,
 output wire[1:0] bist_mode,
 output wire [DATA_WIDTH-1:0] bist_sig_exp,
 //from bist controller
 input wire bist_pass_in,
 input wire bist_fail_in,
 input wire [DATA_WIDTH-1:0] bist_sig_act_in,
 input wire [3:0] err_code_in
 );
 
 //address decode constant
 localparam [3:0] ADDR_CTRL = 4'h0,
                  ADDR_STATUS = 4'h1,
                  ADDR_TX_DATA = 4'h2,
                  ADDR_RX_DATA = 4'h3,
                  ADDR_SIG_EXP = 4'h4,
                  ADDR_SIG_ACT = 4'h5;
                  
//storage register

reg [15:0] ctrl_reg;
reg status_done;
reg status_bist_pass;
reg status_bist_fail;
reg [DATA_WIDTH-1:0] tx_data_reg;
reg [DATA_WIDTH-1:0] bist_sig_exp_reg;

//output wire assignment
assign cpol = 1'b0;// ctrl_reg[5];
assign cpha = 1'b0;// ctrl_reg[6];
assign clk_div = ctrl_reg[15:8];
assign bist_en = ctrl_reg[1];
assign bist_mode = ctrl_reg[4:3];
assign tx_data = tx_data_reg;
assign bist_sig_exp = bist_sig_exp_reg;

//write logic
always @(posedge clk) begin
    if (!rst_n) begin
        ctrl_reg          <= 16'h0400;
        tx_data_reg       <= {DATA_WIDTH{1'b0}};
        bist_sig_exp_reg  <= {DATA_WIDTH{1'b0}};
        spi_en_out        <= 1'b0;
        bist_start_out    <= 1'b0;
        status_done       <= 1'b0;
        status_bist_pass  <= 1'b0;
        status_bist_fail  <= 1'b0;
    end else begin
    
    spi_en_out <= 1'b0;
    bist_start_out <= 1'b0;
    
    if(done_in) status_done <= 1'b1;
    if(bist_pass_in) status_bist_pass <= 1'b1;
    if(bist_fail_in) status_bist_fail <= 1'b1;
    
    if (wr_en) begin
       case(wr_addr) 
       //contrl reg
            ADDR_CTRL: begin
            if(wr_data[0]) spi_en_out <= 1'b1;
            if(wr_data[2]) bist_start_out <=1'b1;
            
            ctrl_reg <= {
                 wr_data[15:8],   // CLK_DIV  [15:8]
                 1'b0,            // reserved  [7]
                 1'b0,            // reserved  [6]
                 1'b0,            // reserved  [5]
                 //wr_data[6],      // CPHA      [6]
                 //wr_data[5],      // CPOL      [5]
                 wr_data[4:3],    // BIST_MODE [4:3]
                 1'b0,            // BIST_START[2] not stored
                 wr_data[1],      // BIST_EN   [1]
                 1'b0             // SPI_EN    [0] not stored
                 };
            end 
       // address reg
       ADDR_STATUS: begin
           // Bit [0] BUSY is live; writes ignored.
           // Writing 1 to bits [1],[2],[3] ? clear.
           if (wr_data[1]) status_done      <= 1'b0;
           if (wr_data[2]) status_bist_pass <= 1'b0;
           if (wr_data[3]) status_bist_fail <= 1'b0;
           end 
      
      //tx_data
      ADDR_TX_DATA: tx_data_reg <= wr_data[DATA_WIDTH-1:0];
      //BIST_sig_exp
      ADDR_SIG_EXP: bist_sig_exp_reg <= wr_data[DATA_WIDTH-1:0];
      
      default: ;//do nothing
      
      endcase
   end
 end
end
     
//read logic
always @(*) begin
rd_data = 16'h0000;
case(rd_addr) 
     ADDR_CTRL: begin
           rd_data=ctrl_reg;
           end
    ADDR_STATUS: begin
           //16 bit status reg
           //[15:8]=0x00 [7:4]=ERR_CODE [3]=BIST_FAIL
           //[2]=BIST_PASS [1]=DONE [0]=BUSY
           rd_data = {
                    8'h00,             // [15:8]  padding
                    err_code_in[3:0],  // [7:4]   ERR_CODE
                    status_bist_fail,  // [3]     BIST_FAIL (sticky)
                    status_bist_pass,  // [2]     BIST_PASS (sticky)
                    status_done,       // [1]     DONE      (sticky)
                    busy_in            // [0]     BUSY      (live)
                };
            end                         
     ADDR_TX_DATA: rd_data = {{(16-DATA_WIDTH){1'b0}}, tx_data_reg};
            
     ADDR_RX_DATA: rd_data = {{(16-DATA_WIDTH){1'b0}}, rx_data_in};
            
     ADDR_SIG_EXP: rd_data = {{(16-DATA_WIDTH){1'b0}}, bist_sig_exp_reg};
            
     ADDR_SIG_ACT: rd_data = {{(16-DATA_WIDTH){1'b0}}, bist_sig_act_in};
            
     default: rd_data = 16'hDEAD; // Invalid address sentinel
  endcase
end                 
endmodule

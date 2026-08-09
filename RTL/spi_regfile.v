`timescale 1ns / 1ps

module spi_regfile#(parameter DATA_WIDTH=8,
                    parameter ADDR_WIDTH=4)
(//system
 input wire clk,
 input wire rst_n,
 //wire port
 input wire wr_en,//write enable pulse
 input wire [ADDR_WIDTH-1:0] wr_addr,//4 bit address selecting the register
 input wire [15:0] wr_data,//16 bit incoming data bus
 //Read port
 input wire[ADDR_WIDTH-1:0] rd_addr, //4 bit address selecting the register
 output reg [15:0] rd_data,//16 bit outgoing data bus
 //to spi master
 output reg spi_en_out,//it is a pulse if enable spi_master start transmission
 output wire cpol,//reserved always 0
 output wire cpha,//reserved always 0
 output wire [7:0] clk_div,
 output wire [DATA_WIDTH-1:0] tx_data,//actual byte master will transmit
 //from spi master
 input wire [DATA_WIDTH-1:0] rx_data_in,
 input wire busy_in,
 input wire done_in,
 //to bist controller
 output wire bist_en,//enable bist
 output reg bist_start_out,//pulse to start bist
 output wire[1:0] bist_mode,//select bist mode
 output wire [DATA_WIDTH-1:0] bist_sig_exp,//golden signature
 //from bist controller
 input wire bist_pass_in,
 input wire bist_fail_in,
 input wire [DATA_WIDTH-1:0] bist_sig_act_in,//actual misr signature
 input wire [3:0] err_code_in//diagnostic error code
 );
 
 //address decode constant
 localparam [3:0] ADDR_CTRL = 4'h0,//addres for control reg
                  ADDR_STATUS = 4'h1,//address for status reg
                  ADDR_TX_DATA = 4'h2,//address for transmited data reg
                  ADDR_RX_DATA = 4'h3,//address for rcvd data register
                  ADDR_SIG_EXP = 4'h4,//address for signature expected reg
                  ADDR_SIG_ACT = 4'h5;//address for signature actual reg
                  
//storage register

reg [15:0] ctrl_reg;//store contol info
reg status_done;//sticky done flag
reg status_bist_pass;//sticky pass flag
reg status_bist_fail;//sticky fail flag
reg [DATA_WIDTH-1:0] tx_data_reg;//store transmit byte
reg [DATA_WIDTH-1:0] bist_sig_exp_reg;//store golden signature

//output wire assignment
assign cpol = 1'b0;// ctrl_reg[5];
assign cpha = 1'b0;// ctrl_reg[6];
assign clk_div = ctrl_reg[15:8];//CTRL 15.........8 00001010 = 10
assign bist_en = ctrl_reg[1];
assign bist_mode = ctrl_reg[4:3];
assign tx_data = tx_data_reg;
assign bist_sig_exp = bist_sig_exp_reg;

//write logic
always @(posedge clk) begin
    if (!rst_n) begin
        ctrl_reg          <= 16'h0400;//ckl div=4 default
        tx_data_reg       <= {DATA_WIDTH{1'b0}};
        bist_sig_exp_reg  <= {DATA_WIDTH{1'b0}};
        spi_en_out        <= 1'b0;
        bist_start_out    <= 1'b0;
        status_done       <= 1'b0;
        status_bist_pass  <= 1'b0;
        status_bist_fail  <= 1'b0;
    end else begin
    
    spi_en_out <= 1'b0;//reset to 0 every cycle
    bist_start_out <= 1'b0;//reset to 0 every cycle
    
    if(done_in) status_done <= 1'b1;
    if(bist_pass_in) status_bist_pass <= 1'b1;
    if(bist_fail_in) status_bist_fail <= 1'b1;
    
    if (wr_en) begin
       case(wr_addr) 
       //contrl reg
            ADDR_CTRL: begin
      /*What it means: "If the host sets bit 0 of wr_data to 1 during a write to ADDR_CTRL,
       pull the spi_en_out signal high (1'b1) on the next clock edge."  
       What it does: spi_en_out is connected to the SPI Master module (spi_master). 
       Raising this signal tells the SPI Master to take the byte in tx_data and begin 
       transmitting it over the physical SPI lines (SCLK, MOSI, SS_N). */
            if(wr_data[0]) spi_en_out <= 1'b1;
    /*What it means: "If the host sets bit 2 of wr_data to 1 during a write to ADDR_CTRL,
     pull the bist_start_out signal high (1'b1) on the next clock edge."  
     What it does: bist_start_out is connected to the BIST Controller module (bist_ctrl). 
     Raising this signal tells the BIST controller to exit its idle state and 
     launch an automated hardware testing sequence.  */        
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
           // Writing 1 to bits [1],[2],[3] to clear=>W1C
/*Action: If the host writes a 1 into bit 1, the hardware resets the status_done flag back to 0.  
Purpose: Clears the "Transaction Done" indicator after the host has processed a completed SPI transaction.*/     
           if (wr_data[1]) status_done <= 1'b0;
/*Action: If the host writes a 1 into bit 2, the hardware resets the status_bist_pass flag back to 0.
Purpose: Clears the "BIST Passed" indicator before launching a new self-test run.*/      
           if (wr_data[2]) status_bist_pass <= 1'b0;
/*Action: If the host writes a 1 into bit 3, the hardware resets the status_bist_fail flag back to 0.
Purpose: Clears the "BIST Failed" indicator so old error states don't contaminate future tests*/       
           if (wr_data[3]) status_bist_fail <= 1'b0;
           end 
      
      //tx_data
      //normal operational data buffer
      /*Destination Module: spi_master (via the tx_data output wire).
        What it does: Stores the outbound data payload byte that the host wants
        to transmit to an external SPI peripheral.  
   Usage Scenario: Used during normal SPI operation. When the host sets SPI_EN = 1,
   the spi_master reads tx_data_reg and shifts this byte out bit-by-bit over the MOSI pin. */
      ADDR_TX_DATA: tx_data_reg <= wr_data[DATA_WIDTH-1:0];
      
      
      //BIST_sig_exp //Diagnostic Golden Benchmark Buffer
      /*Destination Module: bist_ctrl (via the bist_sig_exp output wire).
        What it does: Stores the pre-calculated "Golden Expected Signature".
        Usage Scenario: Used before running a BIST test. The host writes the 
        expected signature to this register. At the end of the self-test sequence
       (S_COMPARE state), bist_ctrl compares this stored golden value against the
       actual hardware signature generated by the misr block to determine whether
       the test PASSES or FAILS.
      */
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
     //Directly assigns the entire 16-bit ctrl_reg storage to rd_data.
           rd_data=ctrl_reg;
           end
    ADDR_STATUS: begin
   /*Constructs a custom 16-bit status word on the fly by concatenating
    several individual status signals together*/
           //[15:8]=0x00 [7:4]=ERR_CODE [3]=BIST_FAIL
           //[2]=BIST_PASS [1]=DONE [0]=BUSY
   /*Allows the host CPU to check whether the core is busy,
    whether an operation finished, whether a test passed/failed,
     and what error code occurred-all in a single read operation.*/        
           rd_data = {
                    8'h00,             // [15:8]  padding
                    err_code_in[3:0],  // [7:4]   ERR_CODE
                    status_bist_fail,  // [3]     BIST_FAIL (sticky)
                    status_bist_pass,  // [2]     BIST_PASS (sticky)
                    status_done,       // [1]     DONE      (sticky)
                    busy_in            // [0]     BUSY      (live)
                };
            end 
     /*Tansmit Buffer Read:- What it does: Takes the 8-bit value stored in tx_data_reg and zero-extends it to fill 16 bits.
       Purpose: Allows the host to read back and verify whatever payload byte was previously staged for SPI transmission.*/                               
     ADDR_TX_DATA: rd_data = {{(16-DATA_WIDTH){1'b0}}, tx_data_reg};
     
     /*Receive Buffer Read:- What it does: Takes the 8-bit incoming data byte (rx_data_in) coming live from spi_master and zero-extends it to 16 bits.
      Purpose: After an SPI transaction finishes, the host reads this register to retrieve the data byte collected over the MISO line. */       
     ADDR_RX_DATA: rd_data = {{(16-DATA_WIDTH){1'b0}}, rx_data_in};
     
     /*Expected signal read:- What it does: Zero-extends the stored 8-bit "Golden Expected Signature" register.
      Purpose: Allows the host CPU to read back the expected signature that was previously pre-loaded for BIST verification.*/       
     ADDR_SIG_EXP: rd_data = {{(16-DATA_WIDTH){1'b0}}, bist_sig_exp_reg};
      
     /*Actual Signal Read:- What it does: Zero-extends the 8-bit live hardware signature coming directly from the output wire of the misr signature module.
       Purpose: Allows diagnostic software to inspect the actual accumulated signature generated by the hardware during test runs.*/       
     ADDR_SIG_ACT: rd_data = {{(16-DATA_WIDTH){1'b0}}, bist_sig_act_in};
            
     default: rd_data = 16'hDEAD; // Invalid address sentinel
  endcase
end                 
endmodule

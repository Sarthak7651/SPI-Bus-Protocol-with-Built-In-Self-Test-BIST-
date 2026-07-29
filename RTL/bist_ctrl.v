`timescale 1ns / 1ps

module bist_ctrl
#(parameter DATA_WIDTH=8,
  parameter WORD_COUNT=8,
  parameter TIMEOUT_VAL=512//max clk cycle to wait for spi done
  )
 ( //system
   input wire clk,
   input wire rst_n,
   //from register file
   input wire bist_start, //1 cycle trigger
   input wire [1:0] bist_mode, //mode select
   input wire [DATA_WIDTH-1:0] bist_sig_exp,//golden signature
   //to register file
   output reg bist_pass, //1 cycle pulse
   output reg bist_fail, //1 cycle pulse
   output reg bist_busy, //high whilw running
   output reg [3:0] err_code,//diagnostic
   //spi master interface
   output reg spi_en, //1 cycle trigger
   input wire spi_done, //transfer complete
   input wire [DATA_WIDTH-1:0] rx_data,//rcvd byte(loopback)
   output reg [DATA_WIDTH-1:0] bist_tx,//pattern to transmit
   //LFSR interfcae
   output reg lfsr_seed_load, //load seed into LFSR
   output reg lfsr_en,//advance lfsr by 1 step 
   input wire [DATA_WIDTH-1:0] lfsr_data,//current lfsr data
   //MISR interface
   output reg misr_en,//capture 1 byte into MISR
   output reg misr_rst, //synchronous reset
   input wire [DATA_WIDTH-1:0] misr_sig,//running signature
   //loopback mux control
   output reg loopback_en //1 = internal loopback
  );
  
  //State Encoding
  localparam [3:0] S_IDLE     = 4'd0,
                   S_CONFIG   = 4'd1,
                   S_GEN      = 4'd2,
                   S_SHIFT    = 4'd3,
                   S_WAIT     = 4'd4,
                   S_CAPTURE  = 4'd5,
                   S_MISR_WAIT= 4'd9,   // 1-cycle settle after last MISR capture
                   S_COMPARE  = 4'd6,
                   S_PASS     = 4'd7,
                   S_FAIL     = 4'd8;
                   
  //internal register
  reg [3:0] state;
  reg [DATA_WIDTH-1:0] sig_exp_latch;
  reg [7:0] word_cnt;
  reg [2:0] bit_pos;//bit position
  reg [9:0] timeout_cnt;//cycle counter in S_WAIT
  
  //bist mode constants
  localparam [DATA_WIDTH-1:0] LOOP_PATTERN = 8'hA5; //mode 0 fixed pattern
  localparam [DATA_WIDTH-1:0] LFSR_SEED = 8'h01; // mode 2 PRBS seed
  
  //FSM
  always @(posedge clk) begin
      if (!rst_n) begin
          state          <= S_IDLE;
          bist_pass      <= 1'b0;
          bist_fail      <= 1'b0;
          bist_busy      <= 1'b0;
          err_code       <= 4'h0;
          spi_en         <= 1'b0;
          bist_tx        <= {DATA_WIDTH{1'b0}};
          lfsr_seed_load <= 1'b0;
          lfsr_en        <= 1'b0;
          misr_en        <= 1'b0;
          misr_rst       <= 1'b0;
          loopback_en    <= 1'b0;
          sig_exp_latch  <= {DATA_WIDTH{1'b0}};
          word_cnt       <= 8'd0;
          bit_pos        <= 3'd0;
          timeout_cnt    <= 10'd0;
      end else begin
      //pulse output goes low on every cycle
              bist_pass      <= 1'b0;
              bist_fail      <= 1'b0;
              spi_en         <= 1'b0;
              lfsr_seed_load <= 1'b0;
              lfsr_en        <= 1'b0;
              misr_en        <= 1'b0;
              misr_rst       <= 1'b0;       
              
     case(state) 
     //  All outputs safe/deasserted.
    //  err_code is NOT cleared here - it is preserved so
   // the host can read it from STATUS_REG after a FAIL.
  //  err_code is cleared at S_CONFIG (next BIST start).
 //  Wait for a 1-cycle bist_start pulse from regfile.
     S_IDLE: begin
//IDLE    - Wait for bist_start pulse from register file  
                 bist_busy   <= 1'b0;
                 loopback_en <= 1'b0;
                 if (bist_start)
                     state <= S_CONFIG;
             end  
        
    S_CONFIG: begin
//CONFIG  - Latch mode/sig, enable loopback, reset MISR, seed LFSR    
                         bist_busy      <= 1'b1;
                         loopback_en    <= 1'b1;
                         misr_rst       <= 1'b1;        // Reset MISR this cycle
                         lfsr_seed_load <= 1'b1;        // LFSR loads LFSR_SEED next posedge
                         sig_exp_latch  <= bist_sig_exp;// Freeze expected sig
                         err_code       <= 4'h0;        // Clear diagnostic from previous run
                         word_cnt       <= WORD_COUNT;
                         bit_pos        <= 3'd0;
                         timeout_cnt    <= 10'd0;
                         state          <= S_GEN;
                     end
    
   S_GEN: begin
//GEN     - Generate next test pattern based on bist_mode
   
                    case (bist_mode)
                    2'b00: begin    //Mode 0: fixed
                    bist_tx <= LOOP_PATTERN;
                    state   <= S_SHIFT;
                    end
                    2'b01: begin   //Mode 1: walk 1s
                    bist_tx <= ({{(DATA_WIDTH-1){1'b0}}, 1'b1} << bit_pos);
                    state   <= S_SHIFT;
                    end
                    2'b10: begin  //Mode 2: PRBS(pseudo random(LFSR))
                    bist_tx  <= lfsr_data; // capture current value
                    lfsr_en  <= 1'b1; // advance for next GEN
                    state    <= S_SHIFT;
                    end
                    default: begin
                     err_code <= 4'h3; //error:invalid mode
                     state <= S_FAIL;
                     end
                  endcase
             end
    
    S_SHIFT: begin
//SHIFT- Pulse spi_en to start one SPI transfer (1 cycle)    
                   spi_en      <= 1'b1;    // 1-cycle pulse
                   timeout_cnt <= 10'd0;   // reset timeout counter
                   state       <= S_WAIT;
             end
                                   
    S_WAIT: begin
//WAIT- Wait for spi_done; timeout ? FAIL with err_code=2    
                   if (spi_done) 
                   begin
                   timeout_cnt <= 10'd0;
                   state       <= S_CAPTURE;
                   end 
                   else if (timeout_cnt >= TIMEOUT_VAL) 
                   begin
                   err_code <= 4'h2;   // timeout error
                   state    <= S_FAIL;
                   end 
                   else 
                   begin
                   timeout_cnt <= timeout_cnt + 10'd1;
                   end
             end
                                             
    S_CAPTURE: begin
//CAPTURE - Enable MISR for 1 cycle, decrement word counter    
                   misr_en  <= 1'b1;               // MISR samples rx_data this cycle
                   word_cnt <= word_cnt - 8'd1;    // count down
                     
                   if (word_cnt == 8'd1) begin     // last word just captured             
                   state <= S_MISR_WAIT;
                   end else begin
                   if (bist_mode == 2'b01)
                   bit_pos <= bit_pos + 3'd1;  // next bit for walking mode
                   state <= S_GEN;
                   end
               end
               
   S_MISR_WAIT: begin
//1 cycle sttele after last misr capture   
                state <= S_COMPARE;
                end
                                
   S_COMPARE: begin
//COMPARE - Compare MISR signature vs expected    
                if(misr_sig == sig_exp_latch) begin
                state <= S_PASS;
                end else begin
                err_code <= 4'h1;//signature miss match
                state<=S_FAIL;
                end
                end
                
   S_PASS: begin
//PASS- Assert bist_pass (1 cycle), release loopback, ? IDLE   
            bist_pass <= 1'b1;
            bist_busy <= 1'b0;
            loopback_en <= 1'b0;
            state <= S_IDLE;
           end
           
  S_FAIL: begin
//FAIL- Assert bist_fail (1 cycle), set err_code, ? IDLE  
            bist_fail <= 1'b1;
            bist_busy <= 1'b0;
            loopback_en <= 1'b0;
            state <=   S_IDLE;
         end
         
  default: state<=S_IDLE;
  endcase
  end
  end                 
                                                                                                                                                                             
endmodule

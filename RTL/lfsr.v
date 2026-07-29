`timescale 1ns / 1ps

module lfsr
#(parameter DATA_WIDTH=8,
  parameter [DATA_WIDTH-1:0] DEFAULT_SEED=8'h01)
  (//system
   input wire clk,
   input wire rst_n,
   //seed control
   input wire seed_load,
   input wire [DATA_WIDTH-1:0] seed_in,
   //shift control
   input wire en,
   //output
   output wire [DATA_WIDTH-1:0] lfsr_data 
    );
    
 /*
      NOTE ON PARAMETERIZATION:
        The feedback tap positions {7,5,4,3} below are specific to
        the 8-bit maximal-length polynomial x^8+x^6+x^5+x^4+1.
        If DATA_WIDTH is changed from 8, the tap positions in
        SECTION 2 MUST be updated to a maximal-length polynomial
        for the new width, otherwise the LFSR will NOT be
        maximal-length (shorter period, possible additional
        zero-lock states). DATA_WIDTH is kept as a parameter for
        documentation/reuse purposes but this project always
        instantiates it at the fixed value of 8.
    */
  //internal reg  
  reg [DATA_WIDTH-1:0] shift_reg;
  assign lfsr_data = shift_reg;
  
  //feedback polynomial
  wire feedback=shift_reg[7] ^ shift_reg[5] ^ shift_reg[4] ^ shift_reg[3];
  
  //seed sanitization
  /*
    If the host ever requests seed_in = 0 (illegal for an XOR-
    feedback LFSR), silently substitute DEFAULT_SEED instead of
    loading the all-zero state.
  */
  wire [DATA_WIDTH-1:0] safe_seed = (seed_in == {DATA_WIDTH{1'b0}}) ? DEFAULT_SEED:seed_in;
   
 //main sequential logic
  always @(posedge clk) begin
    if(!rst_n) begin
       shift_reg <= DEFAULT_SEED;
    end else if(seed_load) begin
       shift_reg <= safe_seed;
    end 
    else if (en) begin
    if(shift_reg == {DATA_WIDTH{1'b0}})
       shift_reg <= DEFAULT_SEED;
    else 
       shift_reg <={shift_reg[DATA_WIDTH-2:0],feedback};
    end 
    //else:hold current vlaue(no seed_load,no en)
end                   
endmodule

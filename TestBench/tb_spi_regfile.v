`timescale 1ns / 1ps

module tb_spi_regfile;
parameter DATA_WIDTH=8;
parameter ADDR_WIDTH=4;
parameter CLK_PERIOD=10;

reg clk;
reg rst_n;
reg wr_en;
reg [ADDR_WIDTH-1:0] wr_addr;
reg [15:0] wr_data;
reg [ADDR_WIDTH-1:0] rd_addr;
wire [15:0] rd_data;

wire spi_en_out;
wire cpol;
wire cpha;
wire [7:0] clk_div;
wire [DATA_WIDTH-1:0] tx_data;
reg [DATA_WIDTH-1:0] rx_data_in;
reg busy_in;
reg done_in;

wire bist_en;
wire bist_start_out;
wire [1:0] bist_mode;
wire [DATA_WIDTH-1:0] bist_sig_exp;
reg bist_pass_in;
reg bist_fail_in;
reg [DATA_WIDTH-1:0] bist_sig_act_in;
reg [3:0] err_code_in;

integer pass_cnt=0;
integer fail_cnt=0;
integer test_num=0;

spi_regfile #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) DUT (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .rd_addr(rd_addr), .rd_data(rd_data),
        .spi_en_out(spi_en_out), .cpol(cpol), .cpha(cpha),
        .clk_div(clk_div), .tx_data(tx_data),
        .rx_data_in(rx_data_in), .busy_in(busy_in), .done_in(done_in),
        .bist_en(bist_en), .bist_start_out(bist_start_out),
        .bist_mode(bist_mode), .bist_sig_exp(bist_sig_exp),
        .bist_pass_in(bist_pass_in), .bist_fail_in(bist_fail_in),
        .bist_sig_act_in(bist_sig_act_in), .err_code_in(err_code_in)
    );

initial clk =0;
always #(CLK_PERIOD/2) clk=~clk;

//helper task
//write a register
task reg_write(input [ADDR_WIDTH-1:0] addr, input [15:0] data);
        begin
            @(posedge clk); #1;
            wr_en = 1; wr_addr = addr; wr_data = data;
            @(posedge clk); #1;
            wr_en = 0;
        end
    endtask

//read
task check(input [64*8:1] label, input [15:0] got, input [15:0] exp);
        begin
            test_num = test_num + 1;
            if (got === exp) begin
                $display("  PASS - %0s : got=%0h", label, got);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL - %0s : got=%0h exp=0x%04h", label, got, exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

//main test
initial begin
    rst_n = 0; wr_en = 0; wr_addr = 0; wr_data = 0; rd_addr = 0;
        rx_data_in = 0; bist_sig_act_in = 0;
        busy_in = 0; done_in = 0; bist_pass_in = 0; bist_fail_in = 0;
        err_code_in = 0; 
    
    repeat(5) @(posedge clk);
    rst_n = 1'b1;
    repeat(2) @(posedge clk); #1;
     
    $display(" register file testbench(mode 0 hardwired) ");
    
    //group-1 basic regsiter operation
    $display("\n core register read/write");
    reg_write(4'h2, 16'h00A5); //TX_DATA
    rd_addr = 4'h2; #1;
    check("TX_DATA readback",rd_data,16'h00A5);
    check("tx_data port", {8'h00, tx_data}, 16'h00A5);
    
    reg_write(4'h4, 16'h00C3);// BIST_SIG_EXP
    rd_addr = 4'h4; #1;
    check("BIST_SIG_EXP readback", rd_data, 16'h00C3);
        
    //group 2: reserved bit [6]/[5]
    $display("\n--- Group 2: CPOL/CPHA bits are now RESERVED ---");
    reg_write(4'h0, 16'h0872);   // same value that used to mean CPHA=1,CPOL=1
            @(posedge clk); #1;
            rd_addr = 4'h0; #1;
    check("CTRL bits[6:5] forced to 0", rd_data, 16'h0812);
    check("cpol port always 0", {15'h0, cpol}, 16'h0000);
    check("cpha port always 0", {15'h0, cpha}, 16'h0000);
    
    reg_write(4'h0, 16'hFF7F);   // try to set every bit including 6,5
            @(posedge clk); #1;
            rd_addr = 4'h0; #1;           
    check("CTRL bits[6:5] still 0 (2nd pattern)", rd_data, 16'hFF1A);
    check("cpol port still 0 (2nd pattern)", {15'h0, cpol}, 16'h0000);
    check("cpha port still 0 (2nd pattern)", {15'h0, cpha}, 16'h0000);
    reg_write(4'h0, 16'h0400);
    
    //group 3: trigger bits still works
    $display("\n--- Group 3: Trigger bits (SPI_EN, BIST_START) ---");
    wr_en = 1; wr_addr = 4'h0; wr_data = 16'h0401; // CLK_DIV=4 + SPI_EN=1
    @(posedge clk); #1;
    check("SPI_EN pulse=1", {15'h0, spi_en_out}, 16'h0001);
    wr_en = 0;
    @(posedge clk); #1;
    check("SPI_EN auto-clear", {15'h0, spi_en_out}, 16'h0000);    

 // ?? Group 4: STATUS_REG sticky + W1C still works ??????
        $display("\n--- Group 4: STATUS_REG sticky bits ---");
        @(posedge clk); #1;
        done_in = 1;
        @(posedge clk); #1;
        done_in = 0;
        @(posedge clk); #1;
        rd_addr = 4'h1; #1;
        check("DONE sticky=1", rd_data[1], 1'b1);
        
        reg_write(4'h1, 16'h0002);  // W1C clear DONE
        @(posedge clk); #1;
        rd_addr = 4'h1; #1;
        check("DONE cleared by W1C", rd_data[1], 1'b0);
 
// ?? Summary ????????????????????????????????????????????
                $display("\n===========================================");
                $display(" RESULT: %0d passed, %0d failed (out of %0d)",
                           pass_cnt, fail_cnt, test_num);
                if (fail_cnt == 0)
                    $display(" ALL TESTS PASSED - CPOL/CPHA reserved-bit behavior confirmed");
                else
                    $display(" SOME TESTS FAILED - check log above");
                $display("===========================================");
         
                $finish;
            end
         
        endmodule                
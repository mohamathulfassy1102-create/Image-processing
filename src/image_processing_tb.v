`timescale 1ns/1ps 
`define INPUTFILENAME		 "input_image.hex" 
`define OUTPUTFILENAME		 "output_IP_INV.bmp"		

module tb_simulation;


reg clk, rst_n;
wire V_sync;
wire H_sync;
wire [7:0] red_0;
wire [7:0] green_0;
wire [7:0] blue_0;
wire [7:0] red_1;
wire [7:0] green_1;
wire [7:0] blue_1;
wire enc_done;

//-------------------------------------------------
// Components
//-------------------------------------------------

image_read 
#(.FILE(`INPUTFILENAME))
	u_image_read
( 
    .clk (clk),
    .rst_n (rst_n),
    .V_sync (V_sync),
    .H_sync (H_sync),
    .red_0 (red_0),
    .green_0 (green_0),
    .blue_0 (blue_0),
    .red_1 (red_1),
    .green_1 (green_1),
    .blue_1 (blue_1),
	.rd_done (enc_done)
); 

image_write 
#(.INFILE(`OUTPUTFILENAME))
	u_image_write
(
	.clk(clk),
	.rst_n(rst_n),
	.hsync(H_sync),
   .DATA_WRITE_R0(red_0),
   .DATA_WRITE_G0(green_0),
   .DATA_WRITE_B0(blue_0),
   .DATA_WRITE_R1(red_1),
   .DATA_WRITE_G1(green_1),
   .DATA_WRITE_B1(blue_1),
	.Write_Done()
);	

initial begin 
    clk = 0;
    forever #10 clk = ~clk;
end

initial begin
    rst_n = 0;
    #25 rst_n = 1;
end
endmodule


`timescale 1ns/1ps

module Project_test();

reg CLOCK_50;
reg RESET_N;
reg [3:0] KEY;
reg [9:0] SW;

wire [6:0] HEX0;
wire [6:0] HEX1;
wire [6:0] HEX2;
wire [6:0] HEX3;
wire [6:0] HEX4;
wire [6:0] HEX5;
wire [9:0] LEDR;
wire [31:0] PC_FE;
wire [31:0] PCPLUS_FE;

Project myprj(
	.CLOCK_50(CLOCK_50),
	.RESET_N(RESET_N),
	.KEY(KEY),
	.SW(SW),
	.HEX0(HEX0),
	.HEX1(HEX1),
	.HEX2(HEX2),
	.HEX3(HEX3),
	.HEX4(HEX4),
	.HEX5(HEX5),
	.LEDR(LEDR),
	.PCFE(PC_FE),
	.PCPLUSFE(PCPLUS_FE)
);

initial begin	
	CLOCK_50 = 0;
	RESET_N = 0;
	KEY = 4'h0;
	SW = 10'h0;
	#20 RESET_N = 1;
end

always #1 CLOCK_50 = ~CLOCK_50;

endmodule

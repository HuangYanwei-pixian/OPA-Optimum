`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHI-Lab
// Engineer: Huang Yanwei
// 
// Create Date: 2020/11/11 12:22:35
// Design Name: OPA_Driver_v2
// Module Name: DPRAM
// Project Name: OPA_Driver_v2
// Target Devices: PYNQ-Z2
// Tool Versions: VIVADO 2019.1
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module DPRAM
#(parameter DATA_WIDTH=24, parameter ADDR_WIDTH=9)
(
	input [(DATA_WIDTH-1):0] data,
	input [(ADDR_WIDTH-1):0] read_addr, write_addr,
	input we, read_clock, write_clock,
	output reg [(DATA_WIDTH-1):0] q
);
	
	// Declare the RAM variable
	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];
	
	always @ (posedge write_clock)
	begin
		// Write
		if (we)
			ram[write_addr] <= data;
	end
	
	always @ (posedge read_clock)
	begin
		// Read 
		q <= ram[read_addr];
	end
	
endmodule

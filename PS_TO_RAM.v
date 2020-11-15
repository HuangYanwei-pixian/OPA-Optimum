`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHI_Lab
// Engineer: Huang Yanwei
// 
// Create Date: 2020/11/03 20:01:01
// Design Name: OPA_Optimum_PYNQ
// Module Name: PS_TO_RAM
// Project Name: OPA_Optimum_PYNQ
// Target Devices: PYNQ-Z2
// Tool Versions: VIVADO 2019.1
// Description: 
//     Receiving voltage data from PS, and store them to a RAM.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module PS_TO_RAM(
    //System signal port
    input clk,
    input rst,
    //PS interface
    input en, //Voltage sending enable, high for valid
    input [23:0]VoltageData, //Voltage data, in RGB mode
    input [8:0]Phi_number, //PA element number, from 1 to 480 
//    output reg status, //Voltage dispatch status, low for idle, high for busy
	
//	output reg [2:0]state_receive,
    //RAM interface
    output reg Send,
    output RAMWrClk,
    output reg RAMWrEn,//RAM writing enable
    output reg[8:0]RAMWrADD,
    output reg[23:0]RAMWrData
     );
    
    assign RAMWrClk = clk;
    // Receive data from PS
    /* 
       For there is no serial port communication in this program, we don't need
    a head frame to sign for a start. Instead, we use a sending enable signal to
    sign for data transimiting.
    */
    parameter IDEL = 3'b001;
    parameter READ = 3'b010;
    parameter DOWN = 3'b100;
    reg status;
    reg [2:0]state_receive;
    reg [8:0]cnt;
    always@(posedge clk or negedge rst)begin
        if(!rst)begin
            state_receive <= IDEL;
            RAMWrADD <= 9'd0;
            RAMWrData <= 24'd0;
            status <= 1'b0;
            Send <= 1'b0;
            RAMWrEn <= 1'b0;
            cnt <= 9'd0;
        end
        else begin
            case(state_receive)
            IDEL:begin
                status <= 1'b0;
                RAMWrEn <= 1'b0;
                cnt <= 9'd0;
                if(en)begin
                    Send <= 1'b0;
                    state_receive <= READ;
                    RAMWrData <= VoltageData;
                    RAMWrADD <= Phi_number;
                    RAMWrEn <= 1'b1;
                    cnt <= cnt + 1'b1;
                end
                else begin
                    state_receive <= state_receive;
                    RAMWrData <= 24'd0;
                    RAMWrADD <= 9'd0;
                end
            end
            READ:begin
                status <= 1'b1;
                RAMWrADD <= Phi_number;
                RAMWrData <= VoltageData;
                RAMWrEn <= 1'b1;
                cnt <= cnt + 1'b1;
                if(cnt == 9'd480)begin
                    Send <= 1'b1;
                    state_receive <= DOWN;
                end
                else begin
                    Send <= 1'b0;
                    state_receive <= state_receive;
                end
            end
            DOWN:begin
                RAMWrEn <= 1'b0;
                state_receive <= IDEL;
            end
            default:state_receive <= IDEL;
            endcase
        end
    end
    
    
endmodule

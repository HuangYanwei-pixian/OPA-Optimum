`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHI_Lab
// Engineer: Originated from Wang Lei on Altera, migrated to Xilinx platform by Huang Yanwei
// 
// Create Date: 2020/11/03 16:59:11
// Design Name: OPA_Optimum_PYNQ
// Module Name: Voltage_Dispatch
// Project Name: OPA_Optimum_PYNQ
// Target Devices: PYNQ-Z2
// Tool Versions: Vivado 2019.1
// Description: 
//     Dispatch voltage data to LCOPA within RGB interface, and generate synchronize signal.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Voltage_Dispatch(
    //System Signal
	input SysClk	,//System Clock
	input Reset_N	,//System	Reset Low Vaild
	//RGB Interface
	output Pclk		,//Clock 25M
	output DEN			,//DEN for RGB interface
	output HSYNC		,//HSYNC for RGB interface
	output VSYNC		,//VSYNC for RGB interface
	output reg[23:0]Data	  ,//RGB data for RGB interface
	
//	output[2:0]	State_S,
	//RAM
	input Send		,//(I)Send Enable
	output RAMRdClk,//(O)24bit RAM Read Clock
//	output RAMRdEn,//(O)24bit RAM Read Enable
	output reg[8:0]RAMRdADD,//(O)24bit RAM Read Address
	input [23:0]RAMRdData //(O)24bit RAM Read Data
    );

	///////////////////////////////////////////////////////////
	//Define parameter
	//宏定义一写ＲＧＢ的列扫描参数
	//屏像素480*800
	//PCLK=帧率(VS)*一行总像素*总行数
	//一行总像素=屏像素(480)+HBP+HFP+HLW(HS低脉宽)
	//总行数 =屏像素(854)+VBP+VFP+VLW(VS低脉宽)
	//VS=25M/806/540=57FPS
	parameter LCD_XSIZE  =16'd480;//
	parameter LCD_YSIZE  =16'd800;//
	///////////////////////////////////////////////////////////
	//列参数定义
	//定义列状态机，三段式
	reg [1:0]		Hsync_state;
	reg [1:0]		Hsync_state_next;
	parameter  	HSPW_state  = 2'd0;
	parameter  	HBPD_state  = 2'd1;
	parameter  	HOZVAL_state= 2'd2;
	parameter  	HFPD_state  = 2'd3;
	//定义列消影与显示参数
	//(HSP+HFP+HBP)*PCLK>=2us    //60*40ns=2400ns
	parameter  	HSPW_num    =8'd40;//40
	parameter  	HBPD_num    =8'd4;//2
	parameter 	HOZVAL_num  =LCD_XSIZE+1'b1;
	parameter  	HFPD_num    =8'd4;//2
	///////////////////////////////////////////////////////////
	//行参数定义
	//定义行状态机，三段式
	reg [1:0]		Vsync_state;
	reg [1:0]		Vsync_state_next;
	parameter  	VSPW_state  = 2'd0;
	parameter  	VBPD_state  = 2'd1;
	parameter  	VOZVAL_state =2'd2;
	parameter  	VFPD_state  = 2'd3;
	//定义行消影与显示参数
	parameter  	VSPW_num     =8'd2;//2
	parameter  	VBPD_num     =8'd2;//2
	parameter 	VOZVAL_num   =LCD_YSIZE+1'b1;
	parameter  	VFPD_num    = 8'd2;//2

	//定义DEN控制信号状态参数
	parameter DEN_HSPW=1'b0;
	parameter DEN_HBPD=1'b0;
	parameter DEN_HOZVAL=1'b1;
	parameter DEN_HFPD=1'b0;
	parameter DEN_VSPW=1'b0;
	parameter DEN_VBPD=1'b0;
	parameter DEN_VFPD=1'b0;

	//定义HS控制信号状态参数
	parameter HSYNC_ACT =1'b1;
	parameter VSYNC_ACT =1'b1;
	parameter HSYNC_SPW		=1'b0;
	parameter HSYNC_BPD		=HSYNC_ACT;
	parameter HSYNC_HOZCAL=HSYNC_ACT;
	parameter HSYNC_FPD		=HSYNC_ACT;
	//定义VS控制信号状态参数
	parameter VSYNC_SPW		=1'b0;
	parameter VSYNC_BPD		=VSYNC_ACT;
	parameter VSYNC_VOZCAL=VSYNC_ACT;
	parameter VSYNC_FPD		=VSYNC_ACT;

	/***************************************************
	目的概述：系统时钟产生PCLK 2分频25M
	功能描述：
	***************************************************/
	reg [1:0] 	SysClk_cnt;

	always @(posedge SysClk or negedge Reset_N)
	begin
		if (!Reset_N)
		begin
			SysClk_cnt <= 2'b0;
		end
		else
		begin
			SysClk_cnt <= SysClk_cnt + 1'b1;
		end
	end

	assign Pclk=SysClk_cnt[0];

	//assign Pclk=SysClk;

	/////////////////////////////////////////////////////////////////
	//////********************列扫描程序部分***********************//

	/***************************************************
	目的概述：列扫描状态机切换参数,三段式
	功能描述：HSPW阶段开始计数
	***************************************************/
	reg  [7:0]	HSPW_cnt;

	always@(negedge Pclk or negedge Reset_N)
	begin
	  if (!Reset_N)
	  begin
			HSPW_cnt<=1'b0;
		end
		else if(Hsync_state_next==HSPW_state)
		begin
			HSPW_cnt<=HSPW_cnt+1'b1;
		end
		else
		begin
		   HSPW_cnt<=1'b0;
		end
	end

	/***************************************************
	目的概述：列扫描状态机切换参数,三段式
	功能描述：HBPD阶段开始计数
	***************************************************/
	reg  [7:0]	HBPD_cnt;

	always@(negedge Pclk or negedge Reset_N)
	begin
	  if(!Reset_N)
	  begin
			HBPD_cnt<=1'b0;
		end
		else if(Hsync_state_next==HBPD_state)
		begin
			HBPD_cnt<=HBPD_cnt+1'b1;
		end
		else
		begin
			HBPD_cnt<=1'b0;
		end
	end

	/***************************************************
	目的概述：列扫描状态机切换参数,三段式
	功能描述：HOZVAL阶段开始计数
	***************************************************/
	reg  [15:0]	HOZVAL_cnt;

	always@(negedge Pclk or negedge Reset_N)
	begin
	  if (!Reset_N)
	  begin
			HOZVAL_cnt<=1'b0;
		end
		else if(Hsync_state_next==HOZVAL_state)
		begin
			HOZVAL_cnt<=HOZVAL_cnt+1'b1;
		end
		else
		begin
		  HOZVAL_cnt<=1'b0;
		end
	end

	/***************************************************
	目的概述：列扫描状态机切换参数,三段式
	功能描述：HFPD阶段开始计数
	***************************************************/
	reg  [7:0]	HFPD_cnt;

	always@(negedge Pclk or negedge Reset_N)
	begin
	  if (!Reset_N)
	  begin
			HFPD_cnt<=1'b0;
		end
		else if(Hsync_state_next==HFPD_state)
		begin
			HFPD_cnt<=HFPD_cnt+1'b1;
		end
		else
		begin
			HFPD_cnt<=1'b0;
		end
	end

	/***************************************************
	目的概述：列扫描状态机切换,三段式
	功能描述：
	***************************************************/

	always@(posedge Pclk or negedge Reset_N)
	begin
		if (!Reset_N)
		begin
			Hsync_state_next<=HSPW_state;
		end
		else
		begin
			case(Hsync_state_next)
			HSPW_state:
			begin
				if(HSPW_cnt==HSPW_num)
				begin
					Hsync_state_next<=HBPD_state;
				end
				else
				begin
					Hsync_state_next<=Hsync_state_next;
				end
			end
			HBPD_state:
			begin
				if(HBPD_cnt==HBPD_num)
				begin
					Hsync_state_next<=HOZVAL_state;
				end
				else
				begin
					Hsync_state_next<=Hsync_state_next;
				end
			end
			HOZVAL_state:
			begin
				if(HOZVAL_cnt==HOZVAL_num)
				begin
					Hsync_state_next<=HFPD_state;
				end
				else
				begin
					Hsync_state_next<=Hsync_state_next;
				end
			end
			HFPD_state:
			begin
				if(HFPD_cnt==HFPD_num)
				begin
					Hsync_state_next<=HSPW_state;
				end
				else
				begin
					Hsync_state_next<=Hsync_state_next;
				end
			end
			default:Hsync_state_next<=HSPW_state;
			endcase
		end
	end

	/***************************************************
	目的概述：列扫描状态机切换,三段式
	功能描述：
	***************************************************/
	always@(negedge Pclk or negedge Reset_N)
	begin
		if(Reset_N==1'b0)
		begin
			Hsync_state<=HSPW_state;
		end
		else
		begin
		   Hsync_state<=Hsync_state_next;
		end
	end

	/***************************************************
	目的概述：列扫描状态机切换,三段式
	功能描述：HSYNC和DEN信号的输出值
	***************************************************/
	reg Hsync_reg;
	reg DEN_H_reg;

	always@(Hsync_state )
	begin
		case(Hsync_state)
		HSPW_state:
		begin
			DEN_H_reg=DEN_HSPW;
			Hsync_reg=HSYNC_SPW;
		end
		HBPD_state:
		begin
			DEN_H_reg=DEN_HBPD;
			Hsync_reg=HSYNC_BPD;
		end
		HOZVAL_state:
		begin
			DEN_H_reg=DEN_HOZVAL;
			Hsync_reg=HSYNC_HOZCAL;
		end
		HFPD_state:
		begin
			DEN_H_reg=DEN_HFPD;
			Hsync_reg=HSYNC_FPD;
		end
		default:
		begin
			DEN_H_reg=DEN_HSPW;
			Hsync_reg=HSYNC_SPW;
		end
		endcase
	end

	assign HSYNC=Hsync_reg;//HSYNC输出赋值


	//////////////////////////////////////////////////////////////////
	///////********************行扫描程序部分***********************//

	/***************************************************
	目的概述：行扫描状态机切换参数
	功能描述：VSPW阶段开始计数
	***************************************************/
	reg  [7:0]VSPW_cnt;

	always@(negedge HSYNC or negedge Reset_N)
	begin
	  if(!Reset_N)
	  begin
			VSPW_cnt<=1'b0;
		end
		else if(Vsync_state_next==VSPW_state)
		begin
			VSPW_cnt<=VSPW_cnt+1'b1;
		end
		else
		begin
		   VSPW_cnt<=1'b0;
		end
	end

	/***************************************************
	目的概述：行扫描状态机切换参数
	功能描述：VBPD阶段开始计数
	***************************************************/
	reg  [7:0]VBPD_cnt;

	always@(negedge HSYNC or negedge Reset_N)
	begin
	  if(!Reset_N)
	  begin
			VBPD_cnt<=1'b0;
		end
		else if(Vsync_state_next==VBPD_state)
		begin
			VBPD_cnt<=VBPD_cnt+1'b1;
		end
		else
		begin
			VBPD_cnt<=1'b0;
		end
	end
	/***************************************************
	目的概述：行扫描状态机切换参数
	功能描述：VOZVAL阶段开始计数
	***************************************************/
	reg  [15:0]VOZVAL_cnt ;

	always@(negedge HSYNC or negedge Reset_N)
	begin
	  if(!Reset_N)
	  begin
			VOZVAL_cnt<=1'b0;
		end
		else if(Vsync_state_next==VOZVAL_state)
		begin
			VOZVAL_cnt<=VOZVAL_cnt+1'b1;
		end
		else
		begin
		   VOZVAL_cnt<=1'b0;
		end
	end

	/***************************************************
	目的概述：行扫描状态机切换参数
	功能描述：VFPD阶段开始计数
	***************************************************/
	reg  [7:0]VFPD_cnt   ;

	always@(negedge HSYNC or negedge Reset_N)
	begin
	   if(!Reset_N)
	   begin
			VFPD_cnt<=1'b0;
		end
		else if(Vsync_state_next==VFPD_state)
		begin
			VFPD_cnt<=VFPD_cnt+1'b1;
		end
		else
		begin
			VFPD_cnt<=1'b0;
		end
	end

	/***************************************************
	目的概述：列扫描状态机切换,三段式
	功能描述：
	***************************************************/

	always@(posedge HSYNC or negedge Reset_N)
	begin
		if(!Reset_N)
		begin
			Vsync_state_next<=VSPW_state;
		end
		else
		begin
			case(Vsync_state_next)
			VSPW_state:
			begin
			  if(VSPW_cnt==VSPW_num)
			  begin
					Vsync_state_next<=VBPD_state;
				end
				else
				begin
					Vsync_state_next<=Vsync_state_next;
				end
			end
			VBPD_state:
			begin
				if(VBPD_cnt==VBPD_num)
				begin
					Vsync_state_next<=VOZVAL_state;
				end
				else
				begin
					Vsync_state_next<=Vsync_state_next;
				end
			end
			VOZVAL_state:
			begin
				if(VOZVAL_cnt==VOZVAL_num)
				begin
					Vsync_state_next<=VFPD_state;
				end
				else
				begin
					Vsync_state_next<=Vsync_state_next;
				end
			end
			VFPD_state:
			begin
				if(VFPD_cnt==VFPD_num)
				begin
					Vsync_state_next<=VSPW_state;
				end
				else
				begin
					Vsync_state_next<=Vsync_state_next;
				end
			end
			default:Vsync_state_next<=VSPW_state;
			endcase
		end
	end

	/***************************************************
	目的概述：列扫描状态机切换,三段式
	功能描述：HSYNC的下降沿赋值状态，即改变状态，比next_state慢半拍
	***************************************************/

	always@(negedge HSYNC or negedge Reset_N)
	begin
		if(!Reset_N)
		begin
			Vsync_state<=VSPW_state;
		end
		else
		begin
		  Vsync_state<=Vsync_state_next;
		end
	end

	/***************************************************
	目的概述：列扫描状态机切换,三段式
	功能描述：VS与DEN状态赋值
	***************************************************/
	reg DEN_V_reg;
	reg Vsync_reg;

	always@(Vsync_state  or DEN_H_reg)
	begin
		case(Vsync_state)
		VSPW_state:
		begin
			Vsync_reg=VSYNC_SPW;
			DEN_V_reg=DEN_VSPW;
		end
		VBPD_state:
		begin
			Vsync_reg=	VSYNC_BPD;
			DEN_V_reg=DEN_VBPD;
		end
		VOZVAL_state:
		begin
			Vsync_reg=VSYNC_VOZCAL;
			DEN_V_reg=DEN_H_reg;
		end
		VFPD_state:
		begin
			Vsync_reg=VSYNC_FPD;
			DEN_V_reg=DEN_VFPD;
		end
		default:
		begin
			Vsync_reg=VSYNC_SPW;
			DEN_V_reg=DEN_VSPW;
		end
		endcase
	end

	assign VSYNC=Vsync_reg;

	////////////////////////////////////////////////////
	///////****************设置数据部分***************//
	////////////////////////////////////////////////////
	reg[2:0]	State_S;
	reg[1:0]	HsReg;

	always @(negedge Pclk or negedge Reset_N)
	begin
		if(!Reset_N)
		begin
			HsReg<=2'b0;
		end
		else
		begin
			HsReg[0]<=HSYNC;
			HsReg[1]<=HsReg[0];
		end
	end

	wire HsTrig = HsReg[0]&(~HsReg[1]);

	reg[1:0]	SendReg;

	always @(negedge SysClk or negedge Reset_N)
	begin
		if(!Reset_N)
		begin
			SendReg<=2'b0;
		end
		else
		begin
			SendReg[0]<=Send;
			SendReg[1]<=SendReg[0];
		end
	end

	//wire SendTrig = SendReg[0]&(~SendReg[1]);
   reg SendTrig = 1'b1;
  /***************************************************
  目的概述:设置输出数据
  功能描述:
  ***************************************************/
	assign			RAMRdClk =SysClk;
	assign 			DEN=DEN_V_reg	;//将列DEN的值赋予DEN
    reg RAMRdEn;
    
	always@(negedge Pclk or negedge Reset_N)
	begin
		if(!Reset_N)
		begin
            RAMRdADD<=9'b0;
            State_S	<=3'd0;
            Data	<=24'b0;
            RAMRdEn <= 1'b0;
		end
		else begin
         case(State_S)
         3'd0:
         begin
         	RAMRdADD<=9'b0;
         	RAMRdEn <= 1'b0;
         	Data		<=24'b0;
         	if(SendTrig)
         	begin
         	 	State_S	<=3'd1;
         	end
         	else
         	begin
         		State_S	<=3'd0;
         	end
         end
         3'd1:
         begin
         	if(HsTrig)
         	begin
         		State_S	<=3'd2;
         	end
         	else
         	begin
         		State_S	<=1'd1;
         	end
         end
         3'd2:
         begin
         	if(HSYNC)begin
         	  RAMRdEn <= 1'b1;
         	  Data		<={RAMRdData[7:0],RAMRdData[15:8],RAMRdData[23:16]};
         	  //State_S	<=3'd2;
         	  RAMRdADD <= RAMRdADD+1'd1;
         	  if(RAMRdADD>=9'd481)
         	  begin
         	  	RAMRdADD<=9'b0;
         	  	RAMRdEn <= 1'b0;
         	  	if(Send)
         	  	begin
         	  		State_S	<=3'd0;
         	  	end
         	  	else
         	  	begin
	   						State_S	<=3'd1;
         	  	end
         	  end
         	end
         	else
         	begin
         		State_S	<=3'd0;
         	end
         end
         default:
         begin
         	State_S	<=3'b0;
         end
    	endcase
		end
	end
    
endmodule

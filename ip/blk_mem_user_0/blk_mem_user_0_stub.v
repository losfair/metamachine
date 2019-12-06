// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
// Date        : Fri Dec  6 11:13:32 2019
// Host        : 6C73 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub u:/metamachine/ip/blk_mem_user_0/blk_mem_user_0_stub.v
// Design      : blk_mem_user_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_4,Vivado 2019.2" *)
module blk_mem_user_0(clka, ena, wea, addra, dina, douta, clkb, enb, web, addrb, 
  dinb, doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,ena,wea[7:0],addra[10:0],dina[63:0],douta[63:0],clkb,enb,web[7:0],addrb[10:0],dinb[63:0],doutb[63:0]" */;
  input clka;
  input ena;
  input [7:0]wea;
  input [10:0]addra;
  input [63:0]dina;
  output [63:0]douta;
  input clkb;
  input enb;
  input [7:0]web;
  input [10:0]addrb;
  input [63:0]dinb;
  output [63:0]doutb;
endmodule

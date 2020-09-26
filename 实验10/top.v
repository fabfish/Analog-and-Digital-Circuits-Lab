`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/12/11 10:33:27
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module top(
input clk,cpu_resetn,//[11:0] rd_data, 
input btnc,
output hs,vs,[11:0]vga_data);

wire clk_65m,lock;
clk_wiz_0 clk_wiz_0(
    .clk_in1 (clk),
    .clk_out1 (clk_65m),
    .reset (~cpu_resetn),
    .locked (lock)
    );
vga_ctrl vga_ctrl(
    .clk (clk_65m),
    .rst (~lock),
 //   .rd_data (rd_data),
    .btnc(btnc),
    .hs (hs),
    .vs (vs),
    .vga_data (vga_data)
    );
endmodule

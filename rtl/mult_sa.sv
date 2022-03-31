//=============================================================================
// Filename      : mult_sa.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-31 10:42:22 PM
// Last Modified : 2022-03-31 10:43:33 PM
//
// Description   : shift-accumulate multiplier, slow but less area
//
//
//=============================================================================
module mult_sa
#(
  parameter int unsigned A_DW = 8,
  parameter int unsigned B_DW = 8,
  // generated parameter
  parameter int unsigned C_DW = A_DW + B_DW
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic [A_DW-1 : 0] a_i,
  input  logic [B_DW-1 : 0] b_i,
  output logic [C_DW-1 : 0] c_o
);

endmodule

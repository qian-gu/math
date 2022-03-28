//=============================================================================
// Filename      : mult_bw.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-26 03:09:07 PM
// Last Modified : 2022-03-28 02:23:52 PM
// Revision      : 0.1.0
//
// Description   : booth-wallace multiplier
//
//=============================================================================
module mult_bw
#(
  parameter int unsigned A_DW = 8,
  parameter int unsigned B_DW = 8,
  // generated parameter
  parameter int unsigned C_DW = A_DW + B_DW
) (
  input  logic [A_DW-1 : 0] a_i,
  input  logic [B_DW-1 : 0] b_i,
  output logic [C_DW-1 : 0] c_o
);

  localparam N_DW = (A_DW < B_DW) ? A_DW : B_DW;
  localparam HALF = N_DW/2;

  logic [HALF : 0][C_DW-1 : 0] pp;
  logic [C_DW-1 : 0]           sum;
  logic [C_DW-1 : 0]           carry;

  mbcodec #(
    .A_DW(A_DW),
    .B_DW(B_DW)
  ) MBCODEC (
    .a_i(a_i),
    .b_i(b_i),
    .pp_o(pp)
  );

  // wallace_tree
  wallace_tree #(
    .DW(C_DW),
    .N (HALF+1)
  ) WALLACE_TREE (
    .add_i(pp),
    .sum_o  (sum),
    .carry_o(carry)
  );

  // cla
  cla #(.DW(C_DW)
  ) CLA (
    .a_i(sum),
    .b_i(carry),
    .s_o(c_o),
    .c_o()
  );

endmodule

//=============================================================================
// Filename      : mult_bw.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-26 03:09:07 PM
// Last Modified : 2022-04-02 09:38:42 PM
//
// Description   : booth-wallace multiplier
//
//=============================================================================
module mult_bw
  import math_pkg::*;
#(
  parameter int unsigned A_DW = 8,
  parameter int unsigned B_DW = 8,
  // generated parameter
  parameter int unsigned C_DW = A_DW + B_DW
) (
  input  logic              tc_mode_i,
  input  logic [A_DW-1 : 0] a_i,
  input  logic [B_DW-1 : 0] b_i,
  output logic [C_DW-1 : 0] c_o
);

  localparam M_DW = (A_DW < B_DW) ? B_DW : A_DW;
  localparam N_DW = (A_DW < B_DW) ? A_DW : B_DW;
  localparam PP = (N_DW%2 == 1) ? (N_DW/2 + 2) : (N_DW/2 + 1);

  logic [A_DW+1 :  0] a_ext;
  logic [B_DW+1 :  0] b_ext;
  logic [M_DW   : -1] m;
  logic [N_DW-1 : -1] n;

  // select multiplicand(m) and multiplier(n), convert a*b ==> m*n,
  // `n` has narrower data width for less partial product
  // 1) A_DW < B_DW: swith a and b position, result in m = b, n = a
  // 2) A_DW >= B_DW: do not switch, so m = a, n = b
  assign a_ext = tc_mode_i ? {a_i[A_DW-1], a_i, 1'b0} : {1'b0, a_i, 1'b0};
  assign b_ext = tc_mode_i ? {b_i[B_DW-1], b_i, 1'b0} : {1'b0, b_i, 1'b0};
  assign m = (M_DW == A_DW) ? a_ext : b_ext;
  assign n = (N_DW == B_DW) ? {b_i, 1'b0} : {a_i, 1'b0};

  logic [PP-1   : 0][C_DW-1 : 0] pp;  // partial product
  logic [C_DW-1 : 0]             sum;
  logic [C_DW-1 : 0]             carry;
  logic                          pp_opt; // pp optimize

`ifdef MATH_MULT_USE_MBE_IV
  localparam USE_MBE_IV = 1;
`else
  localparam USE_MBE_IV = 0;
`endif

  // swith between {mbcodec_i, mbcodec_ii, mbcodec_iii, mbcodec_iv} for different MBE
`ifdef MATH_MULT_USE_MBE_IV
  mbcodec_iv #(
`elsif MATH_MULT_USE_MBE_III
  mbcodec_iii #(
`elsif MATH_MULT_USE_MBE_II
  mbcodec_ii #(
`elsif MATH_MULT_USE_MBE_I
  mbcodec_i #(
`endif
    .M_DW(M_DW),
    .N_DW(N_DW)
  ) MBCODEC (
    .tc_mode_i,
    .m_i (m),
    .n_i (n),
    .pp_o(pp)
  );

  assign pp_opt = (USE_MBE_IV) & (tc_mode_i | ((tc_mode_i == 0) & ~n[N_DW-1]));

  // wallace_tree
  wallace_tree #(
    .DW(C_DW),
    .PP(PP)
  ) WALLACE_TREE (
    .pp_opt_i(pp_opt),
    .add_i   (pp),
    .sum_o   (sum),
    .carry_o (carry)
  );

  // cla
  cla #(.DW(C_DW)
  ) CLA (
    .a_i(sum),
    .b_i(carry),
    .s_o(c_o)
  );

endmodule

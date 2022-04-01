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

  localparam M_DW = (A_DW < B_DW) ? B_DW : A_DW;
  localparam N_DW = (A_DW < B_DW) ? A_DW : B_DW;
  localparam PP = (N_DW%2 == 1) ? (N_DW/2 + 2) : (N_DW/2 + 1);

  logic [M_DW   : -1] m;
  logic [N_DW-1 : -1] n;

  // select multiplicand(m) and multiplier(n), convert a*b ==> m*n,
  // `n` has narrower data width for less partial product
  // 1) A_DW < B_DW: swith a and b position, result in m = b, n = a
  // 2) A_DW >= B_DW: do not switch, so m = a, n = b
  assign m = (M_DW == A_DW) ? {a_i[A_DW-1], a_i, 1'b0} : {b_i[B_DW-1], b_i, 1'b0};
  assign n = (N_DW == B_DW) ? {b_i, 1'b0} : {a_i, 1'b0};

  logic [PP-1   : 0][C_DW-1 : 0] pp;  // partial product
  logic [C_DW-1 : 0]             sum;
  logic [C_DW-1 : 0]             carry;

  // swith between {mbcodec_i, mbcodec_ii, mbcodec_iii, mbcodec_iv} for different MBE
  mbcodec_iv #(
    .M_DW(M_DW),
    .N_DW(N_DW)
  ) MBCODEC (
    .m_i (m),
    .n_i (n),
    .pp_o(pp)
  );

  // wallace_tree
  wallace_tree #(
    .DW(C_DW),
    .PP(PP),
    .PP_OPT(1)  // NOTE: set 1 if using mbcodec_iv, else 0
  ) WALLACE_TREE (
    .add_i  (pp),
    .sum_o  (sum),
    .carry_o(carry)
  );

  // cla
  cla #(.DW(C_DW)
  ) CLA (
    .a_i(sum),
    .b_i(carry),
    .s_o(c_o)
  );

endmodule

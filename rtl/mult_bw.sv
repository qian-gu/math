//=============================================================================
// Filename      : mult_bw.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-26 03:09:07 PM
// Last Modified : 2022-04-21 02:28:57 PM
//
// Description   : booth-wallace multiplier
//
//=============================================================================
module mult_bw
  import math_pkg::*;
#(
  parameter int unsigned ADw = 8,
  parameter int unsigned BDw = 8,
  parameter mbe_e        MBE  = MBE_IV,
  // generated parameter, do NOT override
  localparam int unsigned CDw = ADw + BDw
) (
  input  logic             tc_mode_i,
  input  logic [ADw-1 : 0] a_i,
  input  logic [BDw-1 : 0] b_i,
  output logic [CDw-1 : 0] c_o
);

  localparam int unsigned MDw = (ADw < BDw) ? BDw : ADw;
  localparam int unsigned NDw = (ADw < BDw) ? ADw : BDw;
  localparam int unsigned PP = (NDw%2 == 1) ? (NDw/2 + 2) : (NDw/2 + 1);

  logic [ADw+1 : 0]  a_ext;
  logic [BDw+1 : 0]  b_ext;
  logic [MDw   : -1] m;
  logic [NDw-1 : -1] n;

  // select multiplicand(m) and multiplier(n), convert a*b ==> m*n,
  // `n` has narrower data width for less partial product
  // 1) ADw < BDw: swith a and b position, result in m = b, n = a
  // 2) ADw >= BDw: do not switch, so m = a, n = b
  assign a_ext = tc_mode_i ? {a_i[ADw-1], a_i, 1'b0} : {1'b0, a_i, 1'b0};
  assign b_ext = tc_mode_i ? {b_i[BDw-1], b_i, 1'b0} : {1'b0, b_i, 1'b0};
  assign m = (MDw == ADw) ? a_ext : b_ext;
  assign n = (NDw == BDw) ? {b_i, 1'b0} : {a_i, 1'b0};

  logic [PP-1 : 0][CDw-1 : 0] pp;  // partial product
  logic [CDw-1 : 0]           sum;
  logic [CDw-1 : 0]           carry;
  logic                       pp_opt; // pp optimize

  // swith between {mbcodec_i, mbcodec_ii, mbcodec_iii, mbcodec_iv} for different MBE
  if (MBE == MBE_IV) begin : l_inst_mbe_iv

    mbcodec_iv #(
      .MDw(MDw),
      .NDw(NDw)
    ) MBCODEC_IV (
      .tc_mode_i,
      .m_i (m),
      .n_i (n),
      .pp_o(pp)
    );

  end else if (MBE == MBE_III) begin : l_inst_mbe_iii

    mbcodec_iii #(
      .MDw(MDw),
      .NDw(NDw)
    ) MBCODEC_III (
      .tc_mode_i,
      .m_i (m),
      .n_i (n),
      .pp_o(pp)
    );

  end else if (MBE == MBE_II) begin : l_inst_mbe_ii

    mbcodec_ii #(
      .MDw(MDw),
      .NDw(NDw)
    ) MBCODEC_II (
      .tc_mode_i,
      .m_i (m),
      .n_i (n),
      .pp_o(pp)
    );

  end else if (MBE == MBE_I) begin : l_inst_mbe_i

    mbcodec_i #(
      .MDw(MDw),
      .NDw(NDw)
    ) MBCODEC_I (
      .tc_mode_i,
      .m_i (m),
      .n_i (n),
      .pp_o(pp)
    );

  end

  assign pp_opt = (MBE == MBE_IV) & (tc_mode_i | ((tc_mode_i == 0) & ~n[NDw-1]));

  // wallace_tree
  wallace_tree #(
    .AddendDw(CDw),
    .AddendNum(PP)
  ) WALLACE_TREE (
    .pp_opt_i(pp_opt),
    .addend_i(pp),
    .sum_o   (sum),
    .carry_o (carry)
  );

  // cla
  cla #(
    .Dw(CDw)
  ) CLA (
    .a_i(sum),
    .b_i(carry),
    .s_o(c_o)
  );

endmodule

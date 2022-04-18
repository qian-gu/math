//=============================================================================
// Filename      : mult_sa.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-31 10:42:22 PM
// Last Modified : 2022-04-15 03:29:36 PM
//
// Description   : shift-accumulate multiplier, slow but simpler and smaller
//
//                 Performance
//                 ==============

//                 |  optimize  |  latency (cycles)  | throughput (cycles/calc) |
//                 | ---------- | ------------------ | ------------------------ |
//                 | OPT_BW = 1 |  min{A_DW, B_DW}+1 |     min{A_DW, B_DW}      |
//                 | OPT_BW = 0 |  max{A_DW, B_DW}+1 |     max{A_DW, B_DW}      |
//
//                 CONSTRAIN
//                 ==============
//
//                 - input signals have to stay stable when calculating, i.e., busy_o = 1
//
//                 FEATURE
//                 ==============
//
//                 - work in blocking mode only
//                 - support two optimize strategy: bandwdith(default) and area
//
//                 IMPLEMENTATION
//                 ==============
//
//                diagram: see <Patterson and Hennessy> Figure 3.5
//
//                       accum(M bits)       multiplicand(M bits)
//                     _____________            |
//                    |            |            |
//                    |         ___v__        __v__
//                    |         \    \       /    /
//                    |          \    \_____/    /<------------------------
//                    |           \             /                         |
//                    |            \___________/                          |
//                    |                  |                                |
//                    |                  |                                |
//                    |                  |  -----> sra(MULT)              |
//                    |          ________v___________________             |
//                    |         |            |              |             |
//                    |         |     H      |       L      |<--------- ctrl
//                    |         |____________|______________|            ^
//                    |                 |                                |
//                    |_________________v________________________________|
//
//
//                    | operation |  op_b(M bits) |  H(M+1 bits) |  L(N bits) |
//                    | --------- | ------------- | ------------ | ---------- |
//                    |   MULT    | mulitiplicand |        0     | multiplier |
//
//                    MULT: product = {H, L}
//
//=============================================================================
module mult_sa
#(
  parameter int unsigned A_DW = 8,
  parameter int unsigned B_DW = 8,
  parameter int unsigned OPT_BW = 1,  // default optimize for bandwidth, set 1 to optimize for area
  // generated parameter
  parameter int unsigned C_DW = A_DW + B_DW
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic [1      : 0] tc_mode_i,  // two's complement: 1=signed, 0=unsigned; bit[0] for a_i
  input  logic              en_pi,      // enable pulse
  input  logic [A_DW-1 : 0] a_i,        // multiplicand
  input  logic [B_DW-1 : 0] b_i,        // multiplier
  output logic              busy_o,
  output logic              c_vld_o,    // product valid
  output logic [C_DW-1 : 0] c_o         // product
);

  localparam int unsigned MAX = (A_DW >= B_DW) ? A_DW : B_DW;
  localparam int unsigned MIN = (A_DW >= B_DW) ? B_DW : A_DW;
  localparam int unsigned M_DW = (OPT_BW == 1) ? MAX : MIN;
  localparam int unsigned N_DW = (OPT_BW == 1) ? MIN : MAX;

  logic              a_neg;
  logic              b_neg;
  logic              c_neg;
  logic [A_DW-1 : 0] a_p;    // posetive a_i
  logic [B_DW-1 : 0] b_p;    // posetive b_i
  logic [M_DW-1 : 0] m;      // selected multiplicand
  logic [N_DW-1 : 0] n;      // selected multiplier
  logic [N_DW-1 : 0] shift_en;
  logic [M_DW-1 : 0] adder;
  logic [M_DW   : 0] sum;
  logic [C_DW   : 0] acc;
  logic [C_DW   : 0] product_d;
  logic [C_DW   : 0] product_q;

  // convert to unsigned multiplication
  assign a_neg = tc_mode_i[0] & a_i[A_DW-1];
  assign b_neg = tc_mode_i[1] & b_i[B_DW-1];
  assign c_neg = a_neg ^ b_neg;
  assign a_p = a_neg ? (~a_i+1'b1) : a_i;
  assign b_p = b_neg ? (~b_i+1'b1) : b_i;

  // auto select multiplicand(m) and multiplier(n) depending on optimize strategy
  assign m = (OPT_BW == 1) ? ((A_DW >= B_DW) ? a_p : b_p)  // selet MAX
                           : ((A_DW >= B_DW) ? b_p : a_p); // select MIN
  assign n = (OPT_BW == 1) ? ((A_DW >= B_DW) ? b_p : a_p)  // select MIN
                           : ((A_DW >= B_DW) ? a_p : b_p); // select MAX

  // control calculate iteration
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) shift_en <= '0;
    else shift_en <= {shift_en[N_DW-2 : 0], en_pi};
  end

  // start to accumulate and shift when en_pi is asserted
  assign adder = ((en_pi & n[0]) | (~en_pi & product_q[0])) ? m : '0;
  assign sum = en_pi ? {1'b0, adder} : (adder + product_q[N_DW +: M_DW]);
  assign acc = en_pi ? {sum, n} : {sum, product_q[0 +: N_DW]};
  assign product_d = sra(|tc_mode_i, acc);

  // DFF
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      product_q <= '0;
    end else if (en_pi | (|shift_en)) begin
      product_q <= product_d;
    end
  end

  // regout result
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) c_vld_o <= '0;
    else c_vld_o <= shift_en[N_DW-1];
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) c_o <= '0;
    else c_o <= c_neg ? (~product_q[C_DW-1 : 0]+1'b1) : product_q[C_DW-1 : 0];
  end
  assign busy_o = (|shift_en);

  // shift right arithmetic
  function automatic [C_DW : 0] sra(logic tc_mode, logic [C_DW : 0] p);

    logic [C_DW : 0] p_shift;
    p_shift = tc_mode ? $signed(p) >>> 1 : p >>> 1;
    return p_shift;

  endfunction

  // TODO: add checker
  // 1. check en_pi = 0 when calculating(busy_o==1)
  // 2. check input signals stay stable when calculating(busy_o==1)
`ifndef MATH_CHECK_OFF

  always_ff @(posedge clk_i) begin
    if (rst_ni & busy_o & en_pi) begin
      $error("[ERROR] %m at %0t: en_pi should not be 1 when busy_o is high", $time);
    end
  end

`endif

endmodule

//=============================================================================
// Filename      : mult_sa.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-31 10:42:22 PM
// Last Modified : 2022-04-21 11:00:17 AM
//
// Description   : shift-accumulate multiplier, slow but simpler and smaller
//
//                 Performance
//                 ==============

//                 |  optimize | latency (cycles) | throughput (cycles/calc) |
//                 | --------- | ---------------- | ------------------------ |
//                 | OptBw = 1 |  min{ADw, BDw}+1 |     min{ADw, BDw}        |
//                 | OptBw = 0 |  Max{ADw, BDw}+1 |     Max{ADw, BDw}        |
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
//                    |           |             |
//                    |         __v__         __v__
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
  parameter int unsigned ADw = 8,
  parameter int unsigned BDw = 8,
  parameter int unsigned OptBw = 1,  // default optimize for bandwidth, set 1 to optimize for area
  // generated parameter, do NOT override
  localparam int unsigned CDw = ADw + BDw
) (
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic [1 : 0]     tc_mode_i,  // two's complement: 1=signed, 0=unsigned; bit[0] for a_i
  input  logic             en_pi,      // enable pulse
  input  logic [ADw-1 : 0] a_i,        // multiplicand
  input  logic [BDw-1 : 0] b_i,        // multiplier
  output logic             busy_o,
  output logic             c_valid_o,  // product valid
  output logic [CDw-1 : 0] c_o         // product
);

  localparam int unsigned Max = (ADw >= BDw) ? ADw : BDw;
  localparam int unsigned Min = (ADw >= BDw) ? BDw : ADw;
  localparam int unsigned MDw = (OptBw == 1) ? Max : Min;
  localparam int unsigned NDw = (OptBw == 1) ? Min : Max;

  logic             a_neg;
  logic             b_neg;
  logic             c_neg;
  logic [ADw-1 : 0] a_p;    // posetive a_i
  logic [BDw-1 : 0] b_p;    // posetive b_i
  logic [MDw-1 : 0] m;      // selected multiplicand
  logic [NDw-1 : 0] n;      // selected multiplier
  logic [NDw-1 : 0] shift_en;
  logic [MDw-1 : 0] adder;
  logic [MDw : 0]   sum;
  logic [CDw : 0]   acc;
  logic [CDw : 0]   product_d;
  logic [CDw : 0]   product_q;

  // convert to unsigned multiplication
  assign a_neg = tc_mode_i[0] & a_i[ADw-1];
  assign b_neg = tc_mode_i[1] & b_i[BDw-1];
  assign c_neg = a_neg ^ b_neg;
  assign a_p = a_neg ? (~a_i+1'b1) : a_i;
  assign b_p = b_neg ? (~b_i+1'b1) : b_i;

  // auto select multiplicand(m) and multiplier(n) depending on optimize strategy
  assign m = (OptBw == 1) ? ((ADw >= BDw) ? a_p : b_p)  // selet Max
                          : ((ADw >= BDw) ? b_p : a_p); // select Min
  assign n = (OptBw == 1) ? ((ADw >= BDw) ? b_p : a_p)  // select Min
                          : ((ADw >= BDw) ? a_p : b_p); // select Max

  // control calculate iteration
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) shift_en <= '0;
    else shift_en <= {shift_en[NDw-2 : 0], en_pi};
  end

  // start to accumulate and shift when en_pi is asserted
  assign adder = ((en_pi & n[0]) | (~en_pi & product_q[0])) ? m : '0;
  assign sum = en_pi ? {1'b0, adder} : (adder + product_q[NDw +: MDw]);
  assign acc = en_pi ? {sum, n} : {sum, product_q[0 +: NDw]};
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
    if (!rst_ni) c_valid_o <= '0;
    else c_valid_o <= shift_en[NDw-1];
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) c_o <= '0;
    else c_o <= c_neg ? (~product_q[CDw-1 : 0]+1'b1) : product_q[CDw-1 : 0];
  end
  assign busy_o = (|shift_en);

  // shift right arithmetic
  function automatic [CDw : 0] sra(logic tc_mode, logic [CDw : 0] p);

    logic [CDw : 0] p_shift;
    p_shift = tc_mode ? $signed(p) >>> 1 : p >>> 1;
    return p_shift;

  endfunction

`ifndef MATH_CHECK_OFF

  // TODO: add checker
  // 1. check en_pi = 0 when calculating(busy_o==1)
  // 2. check input signals stay stable when calculating(busy_o==1)

`endif

endmodule

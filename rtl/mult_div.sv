//=============================================================================
// Filename      : mult_div.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-04-15 03:30:06 PM
// Last Modified : 2022-04-21 11:00:05 AM
//
// Description   : shift-accumulate multiplier and divider, slow but simpler and smaller
//
//                 Performance
//                 ==============

//                 |  operation |  latency (cycles)  | throughput (cycles/calc) |
//                 | ---------- | ------------------ | ------------------------ |
//                 |   MULT     |       InDw+1         |           InDw         |
//                 |   DIV      |       InDw+1         |           InDw         |
//
//                 CONSTRAIN
//                 ==============
//
//                 - input operands must have the same data width
//                 - input signals have to stay stable when calculating, i.e., busy_o = 1
//
//                 FEATURE
//                 ==============
//
//                 - work in blocking mode only
//                 - MULT: c_o = b_i * a_i
//                 - DIV: c_o = {a_i/b_i, a_i%b_i}
//                 - DIV.divide-by-zero and overflow follow the RISC-V M extension:
//
//                   | Condition   | Dividend    | Divisor | DIVU       | REMU | DIV         | REM |
//                   | ----------- | ----------- | ------- | ---------- | ---- | ----------- | --- |
//                   | divide-by-0 |     x       |    0    | 2^(InDw)-1 |   x  |    -1       |  x  |
//                   | overflow    | -2^(InDw-1) |   -1    |     -      |   -  | -2^(InDw-1) |  0  |
//
//                 IMPLEMENTATION
//                 ==============
//
//                diagram: see <Patterson and Hennessy> Figure 3.5 and 3.11
//
//                       addend (InDw)          augend (InDw)
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
//                    |                  |  <----- sla(DIV)               |
//                    |          ________v___________________             |
//                    |         |            |              |             |
//                    |         |     H      |       L      |<--------- ctrl
//                    |         |____________|______________|            ^
//                    |                  |                               |
//                    |__________________v_______________________________|
//
//
//                    | operation |  op_b(InDw bits) |  H(InDw+1 bits) |  L(InDw bits) |
//                    | --------- | ---------------- | --------------- | ------------- |
//                    |   MULT    |   mulitiplicand  |        0        |   multiplier  |
//                    |   DIV     |      divisor     |     dividend    |      0        |
//
//                    MULT: product = {H, L}
//                    DIV : {remainder + quotient} = {H, L}
//
//=============================================================================
module mult_div
#(
  parameter int unsigned InDw = 8,
  // generated parameter, do NOT override
  localparam int unsigned OutDw = InDw * 2
) (
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic [1 : 0]       tc_mode_i,  // two's complement: 1=signed, 0=unsigned; bit[0] for a_i
  input  logic               operator_i, // 0 = MULT, 1 = DIV
  input  logic               en_pi,      // enable pulse
  input  logic [InDw-1 : 0]  a_i,        // oprand a
  input  logic [InDw-1 : 0]  b_i,        // oprand b
  output logic               busy_o,
  output logic               div_by_zero_o,
  output logic               div_overflow_o,
  output logic               c_valid_o,  // output valid
  output logic [OutDw-1 : 0] c_o         // output data, PRODUCT or {REMAINDER, QUOTIENT}
);

  localparam logic MULT = 1'b0;
  localparam logic DIV  = 1'b1;

  logic              a_neg;
  logic              b_neg;
  logic              c_neg;
  logic              q_neg;    // quotient negative flag
  logic              r_neg;    // remainder negative flag
  logic [InDw-1 : 0] a;        // posetive a_i
  logic [InDw-1 : 0] b;        // posetive b_i
  logic [InDw-1 : 0] shift_en;
  logic [InDw : 0]   addend;
  logic [InDw : 0]   augend;
  logic [InDw : 0]   sum;
  logic              accum_en;
  logic [OutDw : 0]  accum;
  logic [OutDw : 0]  shift_d;
  logic [OutDw : 0]  shift_q;
  logic [OutDw : 0]  shift_dat;
  logic [InDw-1 : 0] quotient;
  logic [InDw-1 : 0] remainder;

  // convert to unsigned multiplication
  assign a_neg = tc_mode_i[0] & a_i[InDw-1];
  assign b_neg = tc_mode_i[1] & b_i[InDw-1];
  assign c_neg = a_neg ^ b_neg;
  assign q_neg = c_neg;
  assign r_neg = a_neg;
  assign a = (~div_by_zero_o & a_neg) ? (~a_i+1'b1) : a_i;
  assign b = (~div_by_zero_o & b_neg) ? (~b_i+1'b1) : b_i;

  // control calculate iteration
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) shift_en <= '0;
    else shift_en <= {shift_en[InDw-2 : 0], en_pi};
  end

  // initiate/update the addend, get shifted result directly to calculate at en_pi cycle
  assign shift_dat = en_pi ? {(InDw+1)'(0), a} : shift_q;
  assign addend = (operator_i == MULT) ? shift_dat[InDw +: InDw+1] : shift_dat[InDw-1 +: InDw+1];

  // initiate the augend, init with `-b` for DIV
  assign augend = (operator_i == MULT) ? {1'b0, b} : ({1'b1, ~b} + 1'b1);

  // adder
  assign sum = addend + augend;

  // update accumulator
  // 1. MULT: accumulate if current multiplier lsb is 1
  // 2. DIV: accumulate if dividend is bigger than divisor(sum is positive)
  assign accum_en = (operator_i == MULT) ? shift_dat[0] : ~sum[InDw];
  assign accum = accum_en ? {sum, shift_dat[0 +: InDw]} : shift_dat;
  // assemble new shifted data, sra for MULT, sll for DIV
  assign shift_d = (operator_i == MULT) ? sra(|tc_mode_i, accum) : sll(accum, accum_en);

  // DFF
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) shift_q <= '0;
    else if (en_pi | (|shift_en)) shift_q <= shift_d;
  end

  // post-process(restore sign bit) and regout final result
  assign quotient = sign_fix(~div_by_zero_o & q_neg, shift_q[0 +: InDw]);
  assign remainder = sign_fix(~div_by_zero_o & r_neg, shift_q[InDw +: InDw]);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) c_valid_o <= '0;
    else c_valid_o <= shift_en[InDw-1];
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      c_o <= '0;
    end else begin
      if (operator_i == MULT) begin
        c_o <= c_neg ? (~shift_q[OutDw-1 : 0]+1'b1) : shift_q[OutDw-1 : 0];
      end else begin
        c_o <= {remainder, quotient};
      end
    end
  end

  assign busy_o = (|shift_en);
  assign div_by_zero_o = (~|b_i);
  assign div_overflow_o = (&tc_mode_i) & (&a_i[InDw-1]) & ~(|a_i[InDw-2 : 0]) & (&b_i);

  // shift right arithmetic
  function automatic [OutDw : 0] sra(logic tc_mode, logic [OutDw : 0] p);

    logic [OutDw : 0] p_shift;
    p_shift = tc_mode ? $signed(p) >>> 1 : p >>> 1;
    return p_shift;

  endfunction

  // shift lef logical
  function automatic [OutDw : 0] sll(logic [OutDw : 0] p, logic lsb);

    logic [OutDw : 0] p_shift;
    p_shift = lsb ? {p[OutDw : InDw], p[InDw-2 : 0], lsb} : {p[OutDw-1 : 0], lsb};
    return p_shift;

  endfunction

  function automatic [InDw-1 : 0] sign_fix(logic neg, logic [InDw-1 : 0] a);

    logic [InDw-1 : 0] a_fix;
    a_fix = neg ? (~a + 1'b1) : a;
    return a_fix;

  endfunction

`ifndef MATH_CHECK_OFF

  // TODO: add checker
  // 1. check en_pi = 0 when calculating(busy_o==1)
  // 2. check input signals stay stable when calculating(busy_o==1)

`endif

endmodule


//=============================================================================
// Filename      : rnd_sat.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-04-20 04:27:42 PM
// Last Modified : 2022-04-28 03:35:50 PM
//
// Description   : Integer arithmetic rounding and saturation
//
//                 FEATURE
//                 ==============
//
//                InDw-1                 |                    0
//                 ______________________|_____________________
//                |      |\ \ \ \ \ \ \ \|                     |
//                |______|_\_\_\_\_\_\_\_|_____________________|
//                                       |
//                        OutDw-1       0|
//
//                 - shift out LSB and rounding
//                 - 4 direct rounding mode
//                 - 6 nearest rounding mode
//
//                 | round_mode_i   | round mode          |
//                 | -------------- | ------------------- |
//                 |     4'b0000    |   DIRECT_UP         |
//                 |     4'b0001    |   DIRECT_DOWN       |
//                 |     4'b0010    |   DIRECT_TO_ZERO    |
//                 |     4'b0011    |   DIRECT_AWAY_ZERO  |
//                 |     4'b1000    |   NEAREST_UP        |
//                 |     4'b1001    |   NEAREST_DOWN      |
//                 |     4'b1010    |   NEAREST_TO_ZERO   |
//                 |     4'b1011    |   NEAREST_AWAY_ZERO |
//                 |     4'b1100    |   NEAREST_EVEN      |
//                 |     4'b1101    |   NEAREST_ODD       |
//
//                 see: en.wikipedia.org/wiki/Rounding
//
//=============================================================================
module rnd_sat
  import math_pkg::*;
#(
  parameter int unsigned InDw = 32,   // data input width
  parameter int unsigned OutDw = 16,  // data output width
  parameter int unsigned ShiftDw = 4  // round amount width
) (
  input  logic                 tc_mode_i,     // two's complement; 0 = unsigned, 1 = signed
  input  round_mode_e          round_mode_i,  // round mode
  input  logic                 saturate_en_i, // satuate enable
  input  logic [ShiftDw-1 : 0] shift_i,       // shift amount
  input  logic [InDw-1 : 0]    data_i,        // data in
  output logic [OutDw-1 : 0]   data_o         // data out
);

  localparam int unsigned ShiftMax = (2**ShiftDw) - 1;

  localparam logic [1 : 0] EQ_ZERO = 2'd0,
                           EQ_HALF = 2'd1,
                           LT_HALF = 2'd2,
                           GT_HALF = 2'd3;

  typedef enum logic {NOP, INC} round_op_e;

  logic signed [InDw : 0]       data;    // data in
  logic signed [InDw : 0]       data_sr; // data after shift right
  logic signed [InDw : 0]       data_round; // data after round
  logic signed [OutDw-1 : 0]    max;
  logic signed [OutDw-1 : 0]    min;
  logic [ShiftMax-1 : 0][1 : 0] fractions;
  logic [1 : 0]                 fraction;
  round_op_e                round_op;

  // convert unsigned to signed
  assign data = tc_mode_i ? {data_i[InDw-1], data_i} : {1'b0, data_i};
  assign data_sr = data >>> shift_i;

  for(genvar i = 0; i < ShiftMax; i++) begin : l_get_fractions
    if (i == 0) begin : l_shift_0

      assign fractions[i] = EQ_ZERO;

    end else if (i == 1) begin : l_shift_1

      assign fractions[i] = data[0] ? EQ_HALF : EQ_ZERO;
      // always @(*) begin
      //   if (data[0]) fractions[i] = EQ_HALF;
      //   else fractions[i] = EQ_ZERO;
      // end

    end else begin : l_shift_x

      assign fractions[i] = ~(|data[0 +: i]) ? EQ_ZERO :
                            (data[i-1] ? (|data[0 +: i-1] ? GT_HALF : EQ_HALF) : LT_HALF);

    end
  end

  // select out fraction
  always_comb begin
    for (int i = 0; i < ShiftMax; i++) begin
      if (shift_i == i) begin
        fraction = fractions[i];
      end
    end
  end

  always_comb begin
    round_op = NOP;
    if (fraction == EQ_ZERO) begin
      round_op = NOP;
    end else begin
      unique case(round_mode_i)
        DIRECT_UP : begin
          round_op = INC;
        end
        DIRECT_DOWN : begin
          round_op = NOP;
        end
        DIRECT_TO_ZERO : begin
          if (data[InDw]) round_op = INC;
          else round_op = NOP;
        end
        DIRECT_AWAY_ZERO : begin
          if (data[InDw]) round_op = NOP;
          else round_op = INC;
        end
        NEAREST_UP : begin
          if (fraction == LT_HALF) round_op = NOP;
          else round_op = INC;
        end
        NEAREST_DOWN : begin
          if (fraction == GT_HALF) round_op = INC;
          else round_op = NOP;
        end
        NEAREST_TO_ZERO : begin
          if (fraction == LT_HALF) round_op = NOP;
          else if (fraction == GT_HALF) round_op = INC;
          else if (data[InDw]) round_op = INC;
          else round_op = NOP;
        end
        NEAREST_AWAY_ZERO : begin
          if (fraction == LT_HALF) round_op = NOP;
          else if (fraction == GT_HALF) round_op = INC;
          else if (data[InDw]) round_op = NOP;
          else round_op = INC;
        end
        NEAREST_EVEN : begin
          if (fraction == LT_HALF) round_op = NOP;
          else if (fraction == GT_HALF) round_op = INC;
          else if (data_sr[0]) round_op = INC;
          else round_op = NOP;
        end
        NEAREST_ODD : begin
          if (fraction == LT_HALF) round_op = NOP;
          else if (fraction == GT_HALF) round_op = INC;
          else if (data_sr[0]) round_op = NOP;
          else round_op = INC;
        end
        default: begin
          round_op = NOP;
        end
      endcase
    end
  end

  assign data_round = (round_op == INC) ? (data_sr + 1'b1) : data_sr;

  // output
  assign max = {1'b0, {(OutDw-1){1'b1}}};
  assign min = {1'b1, (OutDw-1)'(0)};
  always_comb begin
    if (saturate_en_i) begin
      if (data_round > max) begin
        data_o = max;
      end else if (data_round < min) begin
        data_o = min;
      end else begin
        data_o = data_round[OutDw-1 : 0];
      end
    end else begin
      data_o = data_round[OutDw-1 : 0];
    end
  end

`ifndef MATH_CHECK_OFF

  // TODO: add checker

`endif

endmodule


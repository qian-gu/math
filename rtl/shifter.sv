//=============================================================================
// Filename      : shifter.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-04-19 10:12:04 AM
// Last Modified : 2022-04-21 11:00:33 AM
//
// Description   : logic/arithmetic/barrel shifter
//
//                 FEATURE
//                 ==============
//
//                 - 5 shift mode: sll, srl, sra, slb, srb
//
//                 | shift_mode_i  | shift_mode_i | function               |
//                 | ------------- | ------------ | ---------------------- |
//                 |     3'b000    |      SLL     | shift left logic       |
//                 |     3'b100    |      SRL     | shift right logic      |
//                 |     3'b101    |      SRA     | shift right arithmetic |
//                 |     3'b011    |      SLB     | shift left barrel      |
//                 |     3'b111    |      SRB     | shift right barrel     |
//
//                 encode
//                 ---------
//                 see math_pkg.sv
//
//                 shift_mode_i[1:0]: {00 = logic, 01 = arithmetic, 11 = barrel}
//                 shift_mode_i[2]  : {0 = left, 1 = right}
//
//                 IMPLEMENTATION
//                 ==============
//
//                 cascaded structure, the number of 2:1 mux is Dw
//
// //=============================================================================
module shifter
  import math_pkg::*;
#(
  parameter int unsigned Dw = 8,          // input data width
  // generated parameter, do NOT override
  localparam int unsigned Sw = $clog2(Dw)  // shift amount width
) (
  input  logic [Dw-1   : 0] data_i,       // shift data in
  input  logic [Sw-1   : 0] shift_i,      // shift amount
  input  shift_mode_e       shift_mode_i, // shift mode: {SLL, SRL, SRA, SLB, SRB}
  output logic [Dw-1   : 0] data_o        // shift out data
);

  localparam logic [Sw : 0] MAX = Dw;

  logic [Sw-1 : -1][Dw-1 : 0] sll;
  logic [Sw-1 : -1][Dw-1 : 0] srla;
  logic [Sw-1 : -1][Dw-1 : 0] bsh; // barrel shift result
  logic                       sign;
  logic [Sw-1 : 0]            shift;

  // barrel shift: convert srb to slb, srb(data_i, shift_i) = slb(data_i, Dw-shift_i)
  assign shift = (shift_mode_i == SRB) ? (MAX - shift_i) : shift_i;

  // sll
  assign sll[-1] = data_i;
  // cascade mux
  for (genvar i = 0; i < Sw; i++) begin : l_sll
    assign sll[i] = shift[i] ? {sll[i-1][0 +: (Dw-2**i)], (2**i)'(0)} : sll[i-1];
  end

  // srl, sra
  assign srla[-1] = data_i;
  assign sign = (shift_mode_i == SRA) ? data_i[Dw-1] : 1'b0;
  // cascade mux
  for (genvar i = 0; i < Sw; i++) begin : l_srl_sra
    assign srla[i] = shift[i] ? {{(2**i){sign}}, srla[i-1][(Dw-1) -: (Dw-2**i)]} : srla[i-1];
  end

  // barrel shift
  assign bsh[-1] = data_i;
  // cascade mux
  for (genvar i = 0; i < Sw; i++) begin : l_slb
    assign bsh[i] = shift[i] ? {bsh[i-1][Dw-1-2**i : 0], bsh[i-1][Dw-1 -: 2**i]} : bsh[i-1];
  end

  // mux out
  always_comb begin
    data_o = data_i;
    unique case(shift_mode_i)
      SLL: data_o = sll[Sw-1];
      SRL,
      SRA: data_o = srla[Sw-1];
      SLB,
      SRB: data_o = bsh[Sw-1];
      default: data_o = data_i;
    endcase
  end

`ifndef MATH_CHECK_OFF

  // TODO: add checker

`endif

endmodule


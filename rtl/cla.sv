//=============================================================================
// Filename      : cla.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-28 02:08:25 PM
// Last Modified : 2022-04-21 10:55:11 AM
//
// Description   : carry look-ahead adder
//
//
//=============================================================================
module cla #(
  parameter int unsigned Dw = 8
) (
  input  logic [Dw-1 : 0] a_i,
  input  logic [Dw-1 : 0] b_i,
  output logic [Dw-1 : 0] s_o
);

  logic [Dw/4 : 0] c;

  // break down into 4bit cla block
  assign c[0] = 1'b0;
  for (genvar i = 0; i < Dw/4; i++) begin : l_assemble_cla4
    assign {c[i+1], s_o[4*i +: 4]} = cla_4b(a_i[4*i +: 4], b_i[4*i +: 4], c[i]);
  end

  function automatic logic [4 : 0] cla_4b(logic [3 : 0] a, logic [3 : 0] b, logic ci);

    logic [3 : 0] p;
    logic [3 : 0] g;
    logic [4 : 0] c;
    // generate p & g
    p = a | b;
    g = a & b;
    // generate c
    c[0] = ci;
    c[1] = g[0] | (p[0] & c[0]);
    c[2] = g[1] | (p[1] & g[0]) | (&p[1:0] & c[0]);
    c[3] = g[2] | (p[2] & g[1]) | (&p[2:1] & g[0]) | (&p[2:0] & c[0]);
    c[4] = g[3] | (p[3] & g[2]) | (&p[3:2] & g[1]) | (&p[3:1] & g[0]) | (&p[3:0] & c[0]);
    // generate s & co, co = c[4], s = a ^ b ^ c
    return {c[4], a ^ b ^ c[3:0]};

  endfunction

// synopsys translate_off
`ifdef CLA_CHECK_OFF

  initial assert (Dw%4 == 0) else $fatal("[CLA] %m Dw = %d can not be divided by 4!", Dw);

`endif
// synopsys translate_on

endmodule

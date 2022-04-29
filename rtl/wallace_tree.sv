//=============================================================================
// Filename      : wallace_tree.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-28 02:17:11 PM
// Last Modified : 2022-04-20 10:56:40 PM
//
// Description   : wallace-tree based on compressor32
//
//
//=============================================================================
module wallace_tree #(
  parameter int unsigned AddendDw  = 16,  // addend data width
  parameter int unsigned AddendNum = 5    // addend number
) (
  input  logic                                   pp_opt_i,
  input  logic [AddendNum-1 : 0][AddendDw-1 : 0] addend_i,
  output logic                  [AddendDw-1 : 0] sum_o,
  output logic                  [AddendDw-1 : 0] carry_o
);

  localparam int unsigned Level = AddendNum-2; // number of compressor32

  logic [Level-1 : 0][AddendDw-1 : 0] psum;  // partial sum
  logic [Level-1 : 0][AddendDw-1 : 0] carry;
  logic [Level-1 : 0][AddendDw-1 : 0] carry_shift;

  // wallace tree
  for (genvar l = 0; l < Level; l++) begin : l_compress
    if (l == 0) begin : l_compress_1st
      assign {psum[l], carry[l]} = compressor32(addend_i[0], addend_i[1], addend_i[2]);
    end else begin : l_compress_others
      assign {psum[l], carry[l]} = compressor32(psum[l-1], carry_shift[l-1], addend_i[l+2]);
    end
    // right shift carry 1bit for next level
    assign carry_shift[l] = carry[l] << 1;
  end

  // output
  assign sum_o = pp_opt_i ? psum[Level-2] : psum[Level-1];
  assign carry_o = pp_opt_i ? carry_shift[Level-2] : carry_shift[Level-1];

  function automatic logic [2*AddendDw-1 : 0] compressor32(logic [AddendDw-1 : 0] a,
                                                           logic [AddendDw-1 : 0] b,
                                                           logic [AddendDw-1 : 0] c);

    logic [AddendDw-1 : 0] x;
    logic [AddendDw-1 : 0] y;

    for (int i = 0; i < AddendDw; i++) begin : l_compress
      x[i] = a[i] ^ b[i] ^ c[i];
      y[i] = (a[i] & b[i]) | ((a[i] ^ b[i]) & c[i]);
    end

    return {x, y};

  endfunction

endmodule

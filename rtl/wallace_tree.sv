//=============================================================================
// Filename      : wallace_tree.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-28 02:17:11 PM
// Last Modified : 2022-04-02 09:38:23 PM
//
// Description   : wallace-tree based on compressor32
//
//
//=============================================================================
module wallace_tree #(
  parameter DW = 16,  // partial product data width
  parameter PP = 5    // partial product number
) (
  input  logic                      pp_opt_i,
  input  logic [PP-1 : 0][DW-1 : 0] add_i,
  output logic           [DW-1 : 0] sum_o,
  output logic           [DW-1 : 0] carry_o
);

  localparam HALF = DW/2; // original bit width of multiplicand
  localparam LEVEL = PP-2; // number of compressor32

  logic [LEVEL-1 : 0][DW-1 : 0] psum;
  logic [LEVEL-1 : 0][DW-1 : 0] carry;
  logic [LEVEL-1 : 0][DW-1 : 0] carry_shift;

  // wallace tree
  for (genvar l = 0; l < LEVEL; l++) begin : l_compress
    if (l == 0) begin : l_compress_1st
      // compress
      assign {psum[l], carry[l]} = compressor32(add_i[0], add_i[1], add_i[2]);
    end else begin : l_compress_others
      // compress
      assign {psum[l], carry[l]} = compressor32(psum[l-1], carry_shift[l-1], add_i[l+2]);
    end
    // right shift carry 1bit for next level
    assign carry_shift[l] = carry[l] << 1;
  end

  // output
  assign sum_o = pp_opt_i ? psum[LEVEL-2] : psum[LEVEL-1];
  assign carry_o = pp_opt_i ? carry_shift[LEVEL-2] : carry_shift[LEVEL-1];


  function automatic logic [2*DW-1 : 0] compressor32(logic [DW-1 : 0] a, logic [DW-1 : 0] b,
                                                     logic [DW-1 : 0] c);

    logic [DW-1 : 0] x;
    logic [DW-1 : 0] y;
    for (int i = 0; i < DW; i++) begin : l_compress
      x[i] = a[i] ^ b[i] ^ c[i];
      y[i] = (a[i] & b[i]) | ((a[i] ^ b[i]) & c[i]);
    end
    return {x, y};

  endfunction

endmodule

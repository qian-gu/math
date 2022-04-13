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
      for (genvar i = 0; i < DW; i++) begin
        assign {psum[l][i], carry[l][i]} = compressor32(add_i[0][i], add_i[1][i], add_i[2][i]);
      end
    end else begin : l_compress_others
      // compress
      for (genvar i = 0; i < DW; i++) begin
        assign {psum[l][i], carry[l][i]} = compressor32(psum[l-1][i], carry_shift[l-1][i],
                                                        add_i[l+2][i]);
      end
    end
    // right shift carry 1bit for next level
    assign carry_shift[l] = carry[l] << 1;
  end

  // output
  assign sum_o = pp_opt_i ? psum[LEVEL-2] : psum[LEVEL-1];
  assign carry_o = pp_opt_i ? carry_shift[LEVEL-2] : carry_shift[LEVEL-1];


  function automatic logic [1 : 0] compressor32(logic a, logic b, logic c);

    logic x;
    logic y;
    x = a ^ b ^ c;
    y = (a & b) | ((a ^ b) & c);
    return {x, y};

  endfunction

endmodule

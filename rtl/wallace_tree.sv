//=============================================================================
// Filename      : wallace_tree.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-28 02:17:11 PM
// Last Modified : 2022-03-28 02:18:37 PM
// Revision      : 0.1.0
//
// Description   : wallace-tree based on compressor32
//
//
//=============================================================================
module wallace_tree #(
  parameter DW = 16,
  parameter N  = 5,
  parameter PP_OPT = 0
) (
  input  [N-1 : 0][DW-1 : 0] add_i,
  output          [DW-1 : 0] sum_o,
  output          [DW-1 : 0] carry_o
);

  localparam HALF = DW/2; // original bit width of multiplicand
  localparam LEVEL = N-2; // number of compressor32

  logic [LEVEL-1 : 0][DW-1 : 0] psum;
  logic [LEVEL-1 : 0][DW-1 : 0] carry;
  logic [LEVEL-1 : 0][DW-1 : 0] carry_shift;

  // wallace tree
  // level0
  for (genvar i = 0; i < DW; i++) begin
    if (i < HALF+6) begin
      assign {psum[0][i], carry[0][i]} = compressor32(add_i[0][i], add_i[1][i], add_i[2][i]);
    end else begin
        assign {psum[0][i], carry[0][i]} = 2'b0;
    end
  end
  // level1
  for (genvar i = 0; i < DW; i++) begin
    assign {psum[1][i], carry[1][i]} = compressor32(psum[0][i], carry_shift[0][i], add_i[3][i]);
  end
  // level2
  for (genvar i = 0; i < DW; i++) begin
    assign {psum[2][i], carry[2][i]} = compressor32(psum[1][i], carry_shift[1][i], add_i[4][i]);
  end

  assign carry_shift[0] = carry[0] << 1;
  assign carry_shift[1] = carry[1] << 1;
  assign carry_shift[2] = carry[2] << 1;

if (PP_OPT) begin
  assign sum_o = psum[1];
  assign carry_o = carry_shift[1];
end else begin
  assign sum_o = psum[2];
  assign carry_o = carry_shift[2];
end

  // for (genvar l = 0; l < PP; l++) begin
  //   if (l == 0) begin
  //     assign psum[0] = pp[0];
  //     assign psum[1] = pp[1];
  //     assign psum[2] = pp[2];
  //   end else begin
  //     for (genvar i = 0; i < C_DW; i++) begin
  //       assign {psum[l][i], carry[l][i]} = compressor32(psum[l][i], psum[l+1][i], psum[l+2][i]);
  //     end
  //   end
  // end

  function automatic logic [1 : 0] compressor32(logic a, logic b, logic c);

    logic x;
    logic y;
    x = a ^ b ^ c;
    y = (a & b) | ((a ^ b) & c);
    return {x, y};

  endfunction

endmodule

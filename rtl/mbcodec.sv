//=============================================================================
// Filename      : mbcodec.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-28 02:23:01 PM
// Last Modified : 2022-03-28 02:23:23 PM
// Revision      : 0.1.0
//
// Description   : modified booth encode
//
//=============================================================================
module mbcodec #(
  parameter A_DW = 8,
  parameter B_DW = 8,
  // generated parameter
  localparam C_DW = A_DW + B_DW,
  localparam M_DW = (A_DW < B_DW) ? B_DW : A_DW,
  localparam N_DW = (A_DW < B_DW) ? A_DW : B_DW,
  localparam HALF = N_DW/2
) (
  input  logic [A_DW-1 : 0]           a_i,
  input  logic [B_DW-1 : 0]           b_i,
  output logic [HALF : 0][C_DW-1 : 0] pp_o
);

  // modified booth encoding
  typedef struct packed {
    logic neg;
    logic one;
    logic two;
  } mbe_t;

  logic [M_DW   : -1]          m;
  logic [N_DW-1 : -1]          n;
  mbe_t [HALF-1 : 0]           code;
  logic [HALF-1 : 0]           s;
  logic [HALF-1 : 0][M_DW : 0] pre;

  // select multiplicand(m) and multiplier(n), convert a*b ==> m*n,
  // `n` has narrower data width for less partial product
  // 1) A_DW < B_DW: swith a and b position, result in m = b, n = a
  // 2) A_DW >= B_DW: do not switch, so m = a, n = b
  assign m = (M_DW == A_DW) ? {a_i[A_DW-1], a_i, 1'b0} : {b_i[B_DW-1], b_i, 1'b0};
  assign n = (N_DW == B_DW) ? {b_i, 1'b0} : {a_i, 1'b0};

  // modified booth encode and decode
  for (genvar i = 0; i < HALF; i++) begin
    // encode
    assign code[i] = mbe_enc(n[2*i+1 : 2*i-1]);
    // decode pre
    for (genvar j = 0; j <= M_DW; j++) begin
      assign pre[i][j] = mbe_dec(code[i], m[j -: 2]);
    end
    // rename s for assemble
    assign s[i] = pre[i][M_DW];
  end

  // assemble partial product
  for (genvar n = 0; n <= HALF; n++) begin

    if (n == 0) begin : assemble_1st_pp
      assign pp_o[n] = {(C_DW-3-M_DW)'(0) , ~s[n], s[n], s[n], pre[n][M_DW-1 : 0]};
    end else if (n < HALF) begin : assemble_other_pp
      assign pp_o[n] = {(C_DW-M_DW-4)'(0), 1'b1, ~s[n], pre[n][M_DW-1 : 0], 1'b0, code[n-1].neg} << 2*(n-1);
    end else if (n == HALF) begin : assemble_last_pp
      assign pp_o[n] = {(C_DW-1)'(0), code[n-1].neg} << 2*(n-1);
    end

  end

  function automatic mbe_t mbe_enc(logic [2 : 0] b);

    mbe_t code; // encode result
    code.neg = b[2] & (~b[1] | ~b[0]);
    code.one = b[1] ^ b[0];
    code.two = (~b[2] & b[1] & b[0]) | (b[2] & ~b[1] & ~b[0]);
    return code;

  endfunction

  function automatic logic mbe_dec(mbe_t code, logic [1 : 0] a);

    return code.one & (code.neg ^ a[1]) | code.two & (code.neg ^ a[0]);

  endfunction

endmodule

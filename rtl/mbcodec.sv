//=============================================================================
// Filename      : mbcodec.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-28 02:23:01 PM
// Last Modified : 2022-04-01 03:00:42 PM
//
// Description   : modified booth codec
//
//=============================================================================
// MBE_IV type
module mbcodec_iv #(
  parameter M_DW = 8,
  parameter N_DW = 8,
  // generated parameter, do NOT touch
  localparam C_DW = M_DW + N_DW,
  localparam PP = (N_DW%2 == 1) ? (N_DW/2 + 2) : (N_DW/2 + 1)
) (
  input  logic [M_DW   : -1]             m_i,
  input  logic [N_DW-1 : -1]             n_i,
  output logic [PP-1   :  0][C_DW-1 : 0] pp_o
);

  // number of pre is 1 less to pp because last pp is only made up with last neg
  localparam PRE = PP - 1;

  // modified booth encoding
  typedef struct packed {
    logic neg;
    logic one;
    logic two;
  } mbe_t;

  mbe_t [PRE-1 : 0]           code;  // encode result
  logic [PRE-1 : 0][M_DW : 0] pre;   // decode result
  logic [PRE-1 : 0]           s;     // pre[MSB] alias
  logic [PRE-1 : 0]           ci;    // carry of pre[0] + neg, ci[PRE-1] = d = pre[1] + ci[PRE-2]
  logic                       epsilon;
  logic [2 : 0]               alpha;

  // modified booth encode and decode
  for (genvar i = 0; i < PRE; i++) begin
    // encode
    assign code[i] = mbe_enc(n_i[2*i+1 : 2*i-1]);
    // decode
    if (i == PRE-1) begin : decode_last_pre
      for (genvar j = 0; j <= M_DW; j++) begin
        if (j == 0) begin
          // decode t0 = pre[0]
          assign pre[i][j] = m_i[j] & (n_i[2*i] ^ n_i[2*i-1]);
        end else if (j == 1) begin
          // decode t1 = pre[1]
          assign epsilon = (m_i[0] & n_i[2*i+1]) ^ m_i[1];
          assign pre[i][j] = (code[i].one & epsilon) | (code[i].two & m_i[0]);
          // method 1
          // assign ci[i] = ~(~n_i[2*i+1] | m_i[0]) & ~((n_i[2*i-1] | m_i[1]) & (n_i[2*i] | m_i[1])
          //                                            & (n_i[2*i] | n_i[2*i-1]));
          // method 2
          assign ci[i] = code[i].neg & ~(m_i[0] | (m_i[1] & (n_i[2*i] ^ n_i[2*i-1])));
        end else begin
          // decode pre[M_DW : 2]
          assign pre[i][j] = mbe_dec(code[i], m_i[j -: 2]);
        end
      end
    end else begin : decode_other_pre
      for (genvar j = 0; j <= M_DW; j++) begin
        if (j == 0) begin
          // decode t0 = pre[0]
          assign pre[i][j] = m_i[j] & (n_i[2*i] ^ n_i[2*i-1]);
          // method 1
          // assign ci[i] = n_i[2*i+1] & ((~n_i[2*i] & ~n_i[2*i-1]) |
          //                (~m_i[j] & ~n_i[2*i]) | (~m_i[j] & (n_i[2*i] ^ n_i[2*i-1])));
          // method 2
          // assign ci[i] = n_i[2*i+1] & (~(n_i[2*i] | n_i[2*i-1]) | ~(m_i[j] | n_i[2*i]) |
          //                              ~(m_i[j] | (n_i[2*i] ~^ n_i[2*i-1])));
          // method 3
          assign ci[i] = code[i].neg & (~code[i].one | ~m_i[j]);
        end else begin
          // decode pre[M_DW : 1]
          assign pre[i][j] = mbe_dec(code[i], m_i[j -: 2]);
        end

      end
    end
    // alias for assemble
    assign s[i] = pre[i][M_DW];
  end

  assign alpha[0] = s[0] ~^ (~ci[PRE-1]);
  assign alpha[1] = s[0] & (~ci[PRE-1]);
  assign alpha[2] = ~alpha[1];

  // assemble pre to generate output partial product
  for (genvar i = 0; i < PP; i++) begin

    if (i == 0) begin : assemble_1st_pp
      assign pp_o[i] = {(C_DW-3-M_DW)'(0) , alpha[2], alpha[1], alpha[0], pre[i][M_DW-1 : 0]};
    end else if (i < PP-1) begin : assemble_other_pp
      assign pp_o[i] = {(C_DW-M_DW-3)'(0), 1'b1, ~s[i], pre[i][M_DW-1 : 0], ci[i-1]} << (2*i-1);
    // end else if (i == PP-2) begin : assemble_last_pp
    //   assign pp_o[i] = {(C_DW-M_DW-3)'(0), 1'b1, ~s[i], pre[i][M_DW-1 : 0], ci[i-1]} << (2*i-1);
    end else begin
      assign pp_o[i] = 'd0;  // redundant for signed multiply
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

    // return code.one & (code.neg ^ a[1]) | code.two & (code.neg ^ a[0]);
    return ~((~code.one | code.neg ~^ a[1]) & (~code.two | code.neg ~^ a[0]));

  endfunction

endmodule

// MBE_III type
module mbcodec_iii #(
  parameter M_DW = 8,
  parameter N_DW = 8,
  // generated parameter, do NOT touch
  localparam C_DW = M_DW + N_DW,
  localparam PP = (N_DW%2 == 1) ? (N_DW/2 + 2) : (N_DW/2 + 1)
) (
  input  logic [M_DW   : -1]             m_i,
  input  logic [N_DW-1 : -1]             n_i,
  output logic [PP-1   :  0][C_DW-1 : 0] pp_o
);

  // number of pre is 1 less to pp because last pp is only made up with last neg
  localparam PRE = PP - 1;

  // modified booth encoding
  typedef struct packed {
    logic neg;
    logic one;
    logic two;
  } mbe_t;

  mbe_t [PRE-1 : 0]           code;  // encode result
  logic [PRE-1 : 0][M_DW : 0] pre;   // decode result
  logic [PRE-1 : 0]           s;     // pre[MSB] alias
  logic [PRE-1 : 0]           ci;    // carry of pre[0] + neg

  // modified booth encode and decode
  for (genvar i = 0; i < PRE; i++) begin
    // encode
    assign code[i] = mbe_enc(n_i[2*i+1 : 2*i-1]);
    // decode
    for (genvar j = 0; j <= M_DW; j++) begin
      if (j == 0) begin
        // decode pre[0]
        assign pre[i][j] = m_i[j] & (n_i[2*i] ^ n_i[2*i-1]);
        // method 1
        // assign ci[i] = n_i[2*i+1] & ((~n_i[2*i] & ~n_i[2*i-1]) |
        //                (~m_i[j] & ~n_i[2*i]) | (~m_i[j] & (n_i[2*i] ^ n_i[2*i-1])));
        // method 2
        // assign ci[i] = n_i[2*i+1] & (~(n_i[2*i] | n_i[2*i-1]) | ~(m_i[j] | n_i[2*i]) |
        //                              ~(m_i[j] | (n_i[2*i] ~^ n_i[2*i-1])));
        // method 3
        assign ci[i] = code[i].neg & (~code[i].one | ~m_i[j]);
        // Warning: L60 following method in paper is wrong
        // assign ci[i] = n[2*i+1] & ~((~(n[2*i] | n[2*i-1])) & (~(m[j] | n[2*i])) &
        //                             (~(n[2*i-1] | m[j])));
      end else begin
        // decode pre[M_DW : 1]
        assign pre[i][j] = mbe_dec(code[i], m_i[j -: 2]);
      end
    end
    // alias for assemble
    assign s[i] = pre[i][M_DW];
  end

  // assemble pre to generate output partial product
  for (genvar i = 0; i < PP; i++) begin

    if (i == 0) begin : assemble_1st_pp
      assign pp_o[i] = {(C_DW-3-M_DW)'(0) , ~s[i], s[i], s[i], pre[i][M_DW-1 : 0]};
    end else if (i < PP-1) begin : assemble_other_pp
      assign pp_o[i] = {(C_DW-M_DW-3)'(0), 1'b1, ~s[i], pre[i][M_DW-1 : 0], ci[i-1]} << (2*i-1);
    end else if (i == PP-1) begin : assemble_last_pp
      assign pp_o[i] = {(C_DW-1)'(0), ci[i-1]} << (2*i-1);
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

    // return code.one & (code.neg ^ a[1]) | code.two & (code.neg ^ a[0]);
    return ~((~code.one | code.neg ~^ a[1]) & (~code.two | code.neg ~^ a[0]));

  endfunction

endmodule

// MBE_II type
module mbcodec_ii #(
  parameter M_DW = 8,
  parameter N_DW = 8,
  // generated parameter, do NOT touch
  localparam C_DW = M_DW + N_DW,
  localparam PP = (N_DW%2 == 1) ? (N_DW/2 + 2) : (N_DW/2 + 1)
) (
  input  logic [M_DW   : -1]             m_i,
  input  logic [N_DW-1 : -1]             n_i,
  output logic [PP-1   :  0][C_DW-1 : 0] pp_o
);

  // number of pre is 1 less to pp because last pp is only made up with last neg
  localparam PRE = PP - 1;

  // modified booth encoding
  typedef struct packed {
    logic neg_fix;
    logic neg;
    logic one;
    logic two;
    logic z;
  } mbe_t;

  mbe_t [PRE-1 : 0]           code;  // encode result
  logic [PRE-1 : 0][M_DW : 0] pre;   // decode result
  logic [PRE-1 : 0]           s;     // pre[MSB] alias

  // modified booth encode and decode
  for (genvar i = 0; i < PRE; i++) begin
    // encode
    assign code[i] = mbe_enc(n_i[2*i+1 : 2*i-1]);
    // decode
    for (genvar j = 0; j <= M_DW; j++) begin
      assign pre[i][j] = mbe_dec(code[i], m_i[j -: 2]);
    end
    // alias for assemble
    assign s[i] = pre[i][M_DW];
  end

  // assemble pre to generate output partial product
  for (genvar i = 0; i < PP; i++) begin

    if (i == 0) begin : assemble_1st_pp
      assign pp_o[i] = {(C_DW-3-M_DW)'(0) , ~s[i], s[i], s[i], pre[i][M_DW-1 : 0]};
    end else if (i < PP-1) begin : assemble_other_pp
      assign pp_o[i] = {(C_DW-M_DW-4)'(0), 1'b1, ~s[i], pre[i][M_DW-1 : 0],
                        1'b0, code[i-1].neg_fix} << 2*(i-1);
    end else if (i == PP-1) begin : assemble_last_pp
      assign pp_o[i] = {(C_DW-2)'(0), 1'b0, code[i-1].neg_fix} << 2*(i-1);
    end

  end

  function automatic mbe_t mbe_enc(logic [2 : 0] b);

    mbe_t code; // encode result
    code.neg_fix = b[2] & ~(b[1] & b[0]);
    code.neg = b[2];
    code.one = b[1] ~^ b[0];
    code.two = b[1] ^ b[0];
    code.z = b[2] ~^ b[1];
    return code;

  endfunction

  function automatic logic mbe_dec(mbe_t code, logic [1 : 0] a);

    return ~((code.one | (code.neg ~^ a[1])) & (code.two | code.z | (code.neg ~^ a[0])));

  endfunction

endmodule

// MBE_I type, deprecate due to bigger area
module mbcodec_i #(
  parameter M_DW = 8,
  parameter N_DW = 8,
  // generated parameter, do NOT touch
  localparam C_DW = M_DW + N_DW,
  localparam PP = (N_DW%2 == 1) ? (N_DW/2 + 2) : (N_DW/2 + 1)
) (
  input  logic [M_DW   : -1]             m_i,
  input  logic [N_DW-1 : -1]             n_i,
  output logic [PP-1   :  0][C_DW-1 : 0] pp_o
);

  // modified booth encoding
  typedef struct packed {
    logic neg;
    logic one;
    logic two;
  } mbe_t;

  // number of pre is 1 less to pp because last pp is only made up with last neg
  localparam PRE = PP - 1;

  mbe_t [PRE-1 : 0]           code;  // encode result
  logic [PRE-1 : 0][M_DW : 0] pre;   // decode result
  logic [PRE-1 : 0]           s;     // pre[MSB] alias

  // modified booth encode and decode
  for (genvar i = 0; i < PRE; i++) begin
    // encode
    assign code[i] = mbe_enc(n_i[2*i+1 : 2*i-1]);
    // decode
    for (genvar j = 0; j <= M_DW; j++) begin
      assign pre[i][j] = mbe_dec(code[i], m_i[j -: 2]);
    end
    // alias for assemble
    assign s[i] = pre[i][M_DW];
  end

  // assemble pre to generate output partial product
  for (genvar i = 0; i < PP; i++) begin

    if (i == 0) begin : assemble_1st_pp
      assign pp_o[i] = {(C_DW-3-M_DW)'(0) , ~s[i], s[i], s[i], pre[i][M_DW-1 : 0]};
    end else if (i < PP-1) begin : assemble_other_pp
      assign pp_o[i] = {(C_DW-M_DW-4)'(0), 1'b1, ~s[i], pre[i][M_DW-1 : 0],
                        1'b0, code[i-1].neg} << 2*(i-1);
    end else if (i == PP-1) begin : assemble_last_pp
      assign pp_o[i] = {(C_DW-1)'(0), code[i-1].neg} << 2*(i-1);
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

    // return code.one & (code.neg ^ a[1]) | code.two & (code.neg ^ a[0]);
    return ~((~code.one | code.neg ~^ a[1]) & (~code.two | code.neg ~^ a[0]));

  endfunction

endmodule

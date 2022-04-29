//=============================================================================
// Filename      : mbcodec.sv
// Author        : Qian Gu
// Email         : guqian110@gmail.com
// Created on    : 2022-03-28 02:23:01 PM
// Last Modified : 2022-04-21 02:26:18 PM
//
// Description   : modified booth codec
//
//=============================================================================
// MBE_IV type
module mbcodec_iv #(
  parameter MDw = 8,
  parameter NDw = 8,
  // generated parameter, do NOT touch
  localparam CDw = MDw + NDw,
  localparam PpNum = (NDw%2 == 1) ? (NDw/2 + 2) : (NDw/2 + 1)
) (
  input  logic                          tc_mode_i,
  input  logic [MDw : -1]               m_i,
  input  logic [NDw-1 : -1]             n_i,
  output logic [PpNum-1 : 0][CDw-1 : 0] pp_o
);

  // number of pre is 1 less to pp because last pp is generated seperately
  localparam int unsigned PRE = PpNum - 1;

  // modified booth encoding
  typedef struct packed {
    logic neg;
    logic one;
    logic two;
  } mbe_t;

  mbe_t [PRE-1 : 0]              code;  // encode result
  logic [PRE-1 : 0][MDw : 0]     pre;   // decode result
  logic [PRE-1 : 0]              s;     // pre[MSB] alias
  logic [PRE-1 : 0]              ci;    // carry of pre[0] + neg, ci[PRE-1] = d = pre[1] + ci[PRE-2]
  logic [PpNum-1 : 0][CDw-1 : 0] pp_s;  // signed partial product
  logic [PpNum-1 : 0][CDw-1 : 0] pp_u;  // unsigned partial product
  logic                          add_last;
  logic                          epsilon;
  logic [3 : 0]                  alpha;

  // modified booth encode and decode
  for (genvar i = 0; i < PRE; i++) begin : l_codec
    // encode
    assign code[i] = mbe_enc(n_i[2*i+1 : 2*i-1]);
    // decode
    if (i == PRE-1) begin : l_decode_last_pre
      for (genvar j = 0; j <= MDw; j++) begin : l_decode_p
        if (j == 0) begin : l_decode_p0
          // decode t0 = pre[0]
          assign pre[i][j] = m_i[j] & (n_i[2*i] ^ n_i[2*i-1]);
        end else if (j == 1) begin : l_decode_p1
          // decode t1 = pre[1]
          assign epsilon = (m_i[0] & n_i[2*i+1]) ^ m_i[1];
          assign pre[i][j] = (code[i].one & epsilon) | (code[i].two & m_i[0]);
          // method 1 (paper suboptimal)
          // assign ci[i] = ~(~n_i[2*i+1] | m_i[0]) & ~((n_i[2*i-1] | m_i[1]) & (n_i[2*i] | m_i[1])
          //                                            & (n_i[2*i] | n_i[2*i-1]));
          // method 2 (optimal)
          assign ci[i] = code[i].neg & ~(m_i[0] | (m_i[1] & (n_i[2*i] ^ n_i[2*i-1])));
        end else begin : l_decode_px
          // decode pre[MDw : 2]
          assign pre[i][j] = mbe_dec(code[i], m_i[j -: 2]);
        end
      end
    end else begin : l_decode_other_pre
      for (genvar j = 0; j <= MDw; j++) begin : l_decode_p
        if (j == 0) begin : l_decode_p0
          // decode t0 = pre[0]
          assign pre[i][j] = m_i[j] & (n_i[2*i] ^ n_i[2*i-1]);
          // method 1 (suboptimal)
          // assign ci[i] = n_i[2*i+1] & ((~n_i[2*i] & ~n_i[2*i-1]) |
          //                (~m_i[j] & ~n_i[2*i]) | (~m_i[j] & (n_i[2*i] ^ n_i[2*i-1])));
          // method 2 (suboptimal)
          // assign ci[i] = n_i[2*i+1] & (~(n_i[2*i] | n_i[2*i-1]) | ~(m_i[j] | n_i[2*i]) |
          //                              ~(m_i[j] | (n_i[2*i] ~^ n_i[2*i-1])));
          // method 3 (optimal)
          assign ci[i] = code[i].neg & (~code[i].one | ~m_i[j]);
        end else begin : l_decode_px
          // decode pre[MDw : 1]
          assign pre[i][j] = mbe_dec(code[i], m_i[j -: 2]);
        end

      end
    end
    // alias for assemble
    if (i == 0) begin : l_alias_s0
      assign s[i] = pre[i][MDw];
    end else begin : l_alisa_sx
      assign s[i] = tc_mode_i ? pre[i][MDw] : code[i].neg;
    end
  end

  assign alpha[0] = tc_mode_i ? s[0] ~^ (~ci[PRE-1]) : s[0] ^ ci[PRE-1];
  assign alpha[1] = tc_mode_i ? s[0] & (~ci[PRE-1]) : ((~code[0].neg & s[0] & ci[PRE-1]) |
                                                       code[0].neg &(~s[0] | s[0] ^ ci[PRE-1]));
  assign alpha[2] = tc_mode_i ? ~alpha[1] : code[0].neg & ~(s[0] & ci[PRE-1]);
  assign alpha[3] = tc_mode_i ? '0 : ~code[0].neg | code[0].neg & s[0] & ci[PRE-1];

  // assemble pre to generate signed partial product
  for (genvar i = 0; i < PpNum; i++) begin : l_assemble_singed_pp

    if (i == 0) begin : l_assemble_1st_pp
      assign pp_s[i] = {(CDw-MDw-3)'(0), alpha[2: 0], pre[i][MDw-1 : 0]};
    end else if (i < PpNum-1) begin : l_assemble_other_pp
      assign pp_s[i] = {(CDw-MDw-3)'(0), 1'b1, ~s[i], pre[i][MDw-1 : 0], ci[i-1]} << 2*i-1;
    end else begin : l_assemble_last_pp
      assign pp_s[i] = '0;  // redundant for sigend multiply
    end

  end

  // assemble pre to generate unsigned partial product
  for (genvar i = 0; i < PpNum; i++) begin : l_assemble_unsinged_pp

    if (i == 0) begin : l_assemble_1st_pp
      assign pp_u[i] = {(CDw-MDw-4)'(0), alpha, pre[i][MDw-1 : 0]};
    end else if (i < PpNum-1) begin : l_assemble_other_pp
      assign pp_u[i] = {(CDw-MDw-4)'(0), 1'b1, ~s[i], pre[i], ci[i-1]} << 2*i-1;
    end else if (i == PpNum-1) begin : l_assemble_last_pp
      assign pp_u[i] = add_last ? {(CDw-MDw)'(0), m_i[MDw-1 : 0]} << 2*i : '0;
    end

  end

  assign add_last = (tc_mode_i == 1'b0 & n_i[NDw-1]);

  assign pp_o = tc_mode_i ? pp_s : pp_u;

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
  parameter MDw = 8,
  parameter NDw = 8,
  // generated parameter, do NOT touch
  localparam CDw = MDw + NDw,
  localparam PpNum = (NDw%2 == 1) ? (NDw/2 + 2) : (NDw/2 + 1)
) (
  input  logic                          tc_mode_i,
  input  logic [MDw : -1]               m_i,
  input  logic [NDw-1 : -1]             n_i,
  output logic [PpNum-1 : 0][CDw-1 : 0] pp_o
);

  // number of pre is 1 less to pp because last pp is generated seperately
  localparam int unsigned PRE = PpNum - 1;

  // modified booth encoding
  typedef struct packed {
    logic neg;
    logic one;
    logic two;
  } mbe_t;

  mbe_t [PRE-1 : 0]              code;  // encode result
  logic [PRE-1 : 0][MDw : 0]     pre;   // decode result
  logic [PRE-1 : 0]              s;     // pre[MSB] alias
  logic [PRE-1 : 0]              ci;    // carry of pre[0] + neg
  logic [PpNum-1 : 0][CDw-1 : 0] pp_s;  // signed partial product
  logic [PpNum-1 : 0][CDw-1 : 0] pp_u;  // unsigned partial product
  logic                          add_last;

  // modified booth encode and decode
  for (genvar i = 0; i < PRE; i++) begin : l_codec
    // encode
    assign code[i] = mbe_enc(n_i[2*i+1 : 2*i-1]);
    // decode
    for (genvar j = 0; j <= MDw; j++) begin : l_decode_pre
      if (j == 0) begin : l_decode_p0
        // decode pre[0]
        assign pre[i][j] = m_i[j] & (n_i[2*i] ^ n_i[2*i-1]);
        // method 1 (paper optimal)
        // assign ci[i] = n_i[2*i+1] & ((~n_i[2*i] & ~n_i[2*i-1]) |
        //                (~m_i[j] & ~n_i[2*i]) | (~m_i[j] & (n_i[2*i] ^ n_i[2*i-1])));
        // method 2 (paper optimal)
        // assign ci[i] = n_i[2*i+1] & (~(n_i[2*i] | n_i[2*i-1]) | ~(m_i[j] | n_i[2*i]) |
        //                              ~(m_i[j] | (n_i[2*i] ~^ n_i[2*i-1])));
        // method 3 (optimal)
        assign ci[i] = code[i].neg & (~code[i].one | ~m_i[j]);
        // Warning: following method in paper is wrong
        // assign ci[i] = n[2*i+1] & ~((~(n[2*i] | n[2*i-1])) & (~(m[j] | n[2*i])) &
        //                             (~(n[2*i-1] | m[j])));
      end else begin : l_decode_px
        // decode pre[MDw : 1]
        assign pre[i][j] = mbe_dec(code[i], m_i[j -: 2]);
      end
    end
    // alias for assemble
    assign s[i] = tc_mode_i ? pre[i][MDw] : code[i].neg;
  end

  // assemble pre to generate signed partial product
  for (genvar i = 0; i < PpNum; i++) begin : l_assemble_singed_pp

    if (i == 0) begin : l_assemble_1st_pp
      assign pp_s[i] = {(CDw-MDw-3)'(0), ~s[i], s[i], s[i], pre[i][MDw-1 : 0]};
    end else if (i < PpNum-1) begin : l_assemble_other_pp
      assign pp_s[i] = {(CDw-MDw-3)'(0), 1'b1, ~s[i], pre[i][MDw-1 : 0], ci[i-1]} << 2*i-1;
    end else if (i == PpNum-1) begin : l_assemble_last_pp
      assign pp_s[i] = {(CDw-1)'(0), ci[i-1]} << 2*i-1;
    end

  end

  // assemble pre to generate unsigned partial product
  for (genvar i = 0; i < PpNum; i++) begin : l_assemble_unsinged_pp

    if (i == 0) begin : l_assemble_1st_pp
      assign pp_u[i] = {(CDw-MDw-4)'(0), ~s[i], s[i], s[i], pre[i]};
    end else if (i < PpNum-1) begin : l_assemble_other_pp
      assign pp_u[i] = {(CDw-MDw-4)'(0), 1'b1, ~s[i], pre[i], ci[i-1]} << 2*i-1;
    end else if (i == PpNum-1) begin : l_assemble_last_pp
      assign pp_u[i] = add_last ? {(CDw-MDw-1)'(0), m_i[MDw-1 : 0], ci[i-1]} << 2*i-1
                                : {(CDw-1)'(0), code[i-1].neg} << 2*i-1;
    end

  end

  assign add_last = (tc_mode_i == 1'b0 & n_i[NDw-1]);

  assign pp_o = tc_mode_i ? pp_s : pp_u;

  // encoder
  function automatic mbe_t mbe_enc(logic [2 : 0] b);

    mbe_t code; // encode result
    code.neg = b[2] & (~b[1] | ~b[0]);
    code.one = b[1] ^ b[0];
    code.two = (~b[2] & b[1] & b[0]) | (b[2] & ~b[1] & ~b[0]);
    return code;

  endfunction

  // decoder
  function automatic logic mbe_dec(mbe_t code, logic [1 : 0] a);

    // return code.one & (code.neg ^ a[1]) | code.two & (code.neg ^ a[0]);
    return ~((~code.one | code.neg ~^ a[1]) & (~code.two | code.neg ~^ a[0]));

  endfunction

endmodule

// MBE_II type
module mbcodec_ii #(
  parameter MDw = 8,
  parameter NDw = 8,
  // generated parameter, do NOT touch
  localparam CDw = MDw + NDw,
  localparam PpNum = (NDw%2 == 1) ? (NDw/2 + 2) : (NDw/2 + 1)
) (
  input  logic                          tc_mode_i,
  input  logic [MDw : -1]               m_i,
  input  logic [NDw-1 : -1]             n_i,
  output logic [PpNum-1 : 0][CDw-1 : 0] pp_o
);

  // number of pre is 1 less to pp because last pp is generated seperately
  localparam int unsigned PRE = PpNum - 1;

  // modified booth encoding
  typedef struct packed {
    logic neg_fix;
    logic neg;
    logic one;
    logic two;
    logic z;
  } mbe_t;

  mbe_t [PRE-1 : 0]              code;  // encode result
  logic [PRE-1 : 0][MDw : 0]     pre;   // decode result
  logic [PRE-1 : 0]              s;     // pre[MSB] alias
  logic [PpNum-1 : 0][CDw-1 : 0] pp_s;  // signed partial product
  logic [PpNum-1 : 0][CDw-1 : 0] pp_u;  // unsigned partial product
  logic                          add_last;

  // modified booth encode and decode
  for (genvar i = 0; i < PRE; i++) begin : l_codec
    // encode
    assign code[i] = mbe_enc(n_i[2*i+1 : 2*i-1]);
    // decode
    for (genvar j = 0; j <= MDw; j++) begin : l_decode_px
      assign pre[i][j] = mbe_dec(code[i], m_i[j -: 2]);
    end
    // alias for assemble
    assign s[i] = tc_mode_i ? pre[i][MDw] : code[i].neg_fix;
  end

  // assemble pre to generate signed partial product
  for (genvar i = 0; i < PpNum; i++) begin : l_assemble_singed_pp

    if (i == 0) begin : l_assemble_1st_pp
      assign pp_s[i] = {(CDw-MDw-3)'(0), ~s[i], s[i], s[i], pre[i][MDw-1 : 0]};
    end else if (i < PpNum-1) begin : l_assemble_other_pp
      assign pp_s[i] = {(CDw-MDw-4)'(0), 1'b1, ~s[i], pre[i][MDw-1 : 0], 1'b0,
                        code[i-1].neg_fix} << 2*(i-1);
    end else if (i == PpNum-1) begin : l_assemble_last_pp
      assign pp_s[i] = {(CDw-1)'(0), code[i-1].neg_fix} << 2*(i-1);
    end

  end

  // assemble pre to generate unsigned partial product
  for (genvar i = 0; i < PpNum; i++) begin : l_assemble_unsinged_pp

    if (i == 0) begin : l_assemble_1st_pp
      assign pp_u[i] = {(CDw-MDw-4)'(0), ~s[i], s[i], s[i], pre[i]};
    end else if (i < PpNum-1) begin : l_assemble_other_pp
      assign pp_u[i] = {(CDw-MDw-5)'(0), 1'b1, ~s[i], pre[i], 1'b0, code[i-1].neg_fix} << 2*(i-1);
    end else if (i == PpNum-1) begin : l_assemble_last_pp
      assign pp_u[i] = add_last ? {(CDw-MDw-2)'(0), m_i[MDw-1 : 0], 1'b0, code[i-1].neg_fix}
                                  << 2*(i-1)
                                : {(CDw-1)'(0), code[i-1].neg_fix} << 2*(i-1);
    end

  end

  assign add_last = (tc_mode_i == 1'b0 & n_i[NDw-1]);

  assign pp_o = tc_mode_i ? pp_s : pp_u;

  // encoder
  function automatic mbe_t mbe_enc(logic [2 : 0] b);

    mbe_t code; // encode result
    code.neg_fix = b[2] & ~(b[1] & b[0]);
    code.neg = b[2];
    code.one = b[1] ~^ b[0];
    code.two = b[1] ^ b[0];
    code.z = b[2] ~^ b[1];
    return code;

  endfunction

  // decoder
  function automatic logic mbe_dec(mbe_t code, logic [1 : 0] a);

    return ~((code.one | (code.neg ~^ a[1])) & (code.two | code.z | (code.neg ~^ a[0])));

  endfunction

endmodule

// MBE_I type, deprecate due to bigger area
module mbcodec_i #(
  parameter MDw = 8,
  parameter NDw = 8,
  // generated parameter, do NOT touch
  localparam CDw = MDw + NDw,
  localparam PpNum = (NDw%2 == 1) ? (NDw/2 + 2) : (NDw/2 + 1)
) (
  input  logic                          tc_mode_i,
  input  logic [MDw : -1]               m_i,
  input  logic [NDw-1 : -1]             n_i,
  output logic [PpNum-1 : 0][CDw-1 : 0] pp_o
);

  // modified booth encoding
  typedef struct packed {
    logic neg;
    logic one;
    logic two;
  } mbe_t;

  // number of pre is 1 less to pp because last pp is generated seperately
  localparam int unsigned PRE = PpNum-1;

  mbe_t [PRE-1 : 0]              code;  // encode result
  logic [PRE-1 : 0][MDw : 0]     pre;   // decode result
  logic [PRE-1 : 0]              s;     // pre[MSB] alias
  logic [PpNum-1 : 0][CDw-1 : 0] pp_s;  // signed partial product
  logic [PpNum-1 : 0][CDw-1 : 0] pp_u;  // unsigned partial product
  logic                          add_last;

  // modified booth encode and decode
  for (genvar i = 0; i < PRE; i++) begin : l_codec
    // encode
    assign code[i] = mbe_enc(n_i[2*i+1 : 2*i-1]);
    // decode
    for (genvar j = 0; j <= MDw; j++) begin : l_decode_px
      assign pre[i][j] = mbe_dec(code[i], m_i[j -: 2]);
    end
    // alias for assemble
    assign s[i] = tc_mode_i ? pre[i][MDw] : code[i].neg;
  end

  // assemble pre to generate signed partial product
  for (genvar i = 0; i < PpNum; i++) begin : l_assemble_singed_pp

    if (i == 0) begin : l_assemble_1st_pp
      assign pp_s[i] = {(CDw-MDw-3)'(0), ~s[i], s[i], s[i], pre[i][MDw-1 : 0]};
    end else if (i < PpNum-1) begin : l_assemble_other_pp
      assign pp_s[i] = {(CDw-MDw-4)'(0), 1'b1, ~s[i], pre[i][MDw-1 : 0], 1'b0,
                        code[i-1].neg} << 2*(i-1);
    end else if (i == PpNum-1) begin : l_assemble_last_pp
      assign pp_s[i] = {(CDw-1)'(0), code[i-1].neg} << 2*(i-1);
    end

  end

  // assemble pre to generate unsigned partial product
  for (genvar i = 0; i < PpNum; i++) begin : l_assemble_unsinged_pp

    if (i == 0) begin : l_assemble_1st_pp
      assign pp_u[i] = {(CDw-MDw-4)'(0), ~s[i], s[i], s[i], pre[i]};
    end else if (i < PpNum-1) begin : l_assemble_other_pp
      assign pp_u[i] = {(CDw-MDw-5)'(0), 1'b1, ~s[i], pre[i], 1'b0, code[i-1].neg} << 2*(i-1);
    end else if (i == PpNum-1) begin : l_assemble_last_pp
      assign pp_u[i] = add_last ? {(CDw-MDw-2)'(0), m_i[MDw-1 : 0], 1'b0, code[i-1].neg}
                                  << 2*(i-1)
                                : {(CDw-1)'(0), code[i-1].neg} << 2*(i-1);
    end

  end

  assign add_last = (tc_mode_i == 1'b0 & n_i[NDw-1]);

  assign pp_o = tc_mode_i ? pp_s : pp_u;

  // encoder
  function automatic mbe_t mbe_enc(logic [2 : 0] b);

    mbe_t code; // encode result
    code.neg = b[2] & (~b[1] | ~b[0]);
    code.one = b[1] ^ b[0];
    code.two = (~b[2] & b[1] & b[0]) | (b[2] & ~b[1] & ~b[0]);
    return code;

  endfunction

  // decoder
  function automatic logic mbe_dec(mbe_t code, logic [1 : 0] a);

    // return code.one & (code.neg ^ a[1]) | code.two & (code.neg ^ a[0]);
    return ~((~code.one | code.neg ~^ a[1]) & (~code.two | code.neg ~^ a[0]));

  endfunction

endmodule

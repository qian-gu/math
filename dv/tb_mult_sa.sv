`timescale 1ns / 1ns

module tb_mult_sa;

  // clock
  parameter FREQ = 1_000_000;

  localparam PERIOD = 1_000_000_000 / FREQ;
  localparam HALF_PERIOD = PERIOD / 2;

  logic clk_i;
  logic rst_ni;


  always #(HALF_PERIOD) clk_i = ~clk_i;

  // DUT parameter
  parameter A_DW = 8;
  parameter B_DW = 4;
  parameter OPT_BW = 0;

  // simulation parameter
  parameter MAX = 2**(A_DW+B_DW);  // iterate all situation

  // simulation setting up
  logic [A_DW+B_DW : 0]   cnt;
  logic [1 : 0]           tc_mode_i;
  logic                   en_pi;
  logic [A_DW-1 : 0]      a_i;
  logic [B_DW-1 : 0]      b_i;
  logic                   c_vld_o;
  logic                   busy_o;
  logic [A_DW+B_DW-1 : 0] c_o;
  logic [A_DW+B_DW-1 : 0] c;

  logic init;
  logic init_q;
  logic init_p;

  assign init = (cnt == 0);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) init_q <= '0;
    else init_q <= init;
  end
  assign init_p = init & (~init_q);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) en_pi <= '0;
    else en_pi <= init_p | c_vld_o;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) cnt <= 0;
    else if (cnt < MAX) begin
      if (c_vld_o) begin
        cnt <= cnt + 1;
        if (c !== c_o) begin
          $error("Error! a * b = %d * %d = %d != golden %d", a_i, b_i, c_o, c);
          $finish;
        end
      end
    end else if (cnt == MAX) begin
      $display("******************************");
      $display("Simulation Finsh Successfully!");
      $display("******************************");
      $finish;
    end
  end

  always_comb begin
    case(tc_mode_i)
      2'b00: c = $unsigned(a_i) * $unsigned(b_i);
      2'b01: c = $signed(a_i) * $signed({1'b0, b_i});
      2'b10: c = $signed({1'b0, a_i}) * $signed(b_i);
      2'b11: c = $signed(a_i) * $signed(b_i);
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) a_i <= '0;
    else if (c_vld_o) a_i <= a_i + 1;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) b_i <= '0;
    else if (c_vld_o & (a_i == '1)) b_i <= b_i + 1;
  end

  mult_sa #(
    .A_DW(A_DW),
    .B_DW(B_DW),
    .OPT_BW(OPT_BW)
  ) MULT_SA (
    .*
  );

  initial begin
    $dumpfile("sim.vcd");
    $dumpvars;
    clk_i = 1;
    rst_ni = 0;
    tc_mode_i = 2'b00;
    a_i = 0;
    b_i = 0;
    en_pi = 0;
    #(2*PERIOD);
    rst_ni = 1;

  end

endmodule

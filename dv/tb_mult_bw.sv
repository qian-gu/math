`timescale 1ns / 1ns

module tb_mult_bw;

  // clock
  parameter FREQ = 1_000_000;

  localparam PERIOD = 1_000_000_000 / FREQ;
  localparam HALF_PERIOD = PERIOD / 2;

  logic clk;
  logic rst_n;
  logic [A_DW+B_DW : 0] cnt;


  always #(HALF_PERIOD) clk = ~clk;

  // DUT parameter
  parameter A_DW = 8;
  parameter B_DW = 8;

  // simulation parameter
  parameter MAX = 2**(A_DW+B_DW);  // iterate all situation

  // simulation setting up
  logic                    tc_mode_i;
  logic  [A_DW-1 : 0]      a_i;
  logic  [B_DW-1 : 0]      b_i;
  logic  [A_DW+B_DW-1 : 0] c_o;
  logic  [A_DW+B_DW-1 : 0] c;
  logic  [A_DW+B_DW-1 : 0] c_s;
  logic  [A_DW+B_DW-1 : 0] c_u;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 0;
    else if (cnt < MAX) begin
      cnt <= cnt + 1;
      if (c !== c_o) begin
        $error("Error! a * b = %d * %d = %d != golden %d", a_i, b_i, c_o, c);
        $finish;
      end
    end else if (cnt == MAX) begin
      $display("Simulation finshed!");
      $finish;
    end
  end

  assign c_s = $signed(a_i) * $signed(b_i);
  assign c_u = $unsigned(a_i) * $unsigned(b_i);
  assign c = tc_mode_i ? c_s : c_u;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) a_i <= '0;
    else a_i <= a_i + 1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) b_i <= '0;
    else if (a_i == '1) b_i <= b_i + 1;
  end

  mult_bw #(
    .A_DW(A_DW),
    .B_DW(B_DW)
  ) MULT_BW (
    .*
  );

  initial begin
    $dumpfile("sim.vcd");
    // $dumpvars(0, U_COUNTER);
    $dumpvars;
    clk = 1;
    rst_n = 0;
    tc_mode_i = 1;
    a_i = 0;
    b_i = 0;
    #(2*PERIOD);
    rst_n = 1;

  end

endmodule

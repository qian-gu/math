`timescale 1ns / 1ns

module tb_mult_bw;

  // clock
  localparam FREQ        = 1_000_000;
  localparam PERIOD      = 1_000_000_000 / FREQ;
  localparam HALF_PERIOD = PERIOD / 2;

  logic clk;
  logic rst_n;
  logic [ADw+BDw : 0] cnt;

  always #(HALF_PERIOD) clk = ~clk;

  // DUT parameter
  parameter ADw = 8;
  parameter BDw = 8;

  // simulation parameter
  parameter MAX = 2**(ADw+BDw);  // iterate all situation

  // simulation setting up
  logic                  tc_mode_i;
  logic  [ADw-1 : 0]     a_i;
  logic  [BDw-1 : 0]     b_i;
  logic  [ADw+BDw-1 : 0] c_o;
  logic  [ADw+BDw-1 : 0] c;
  logic  [ADw+BDw-1 : 0] c_s;
  logic  [ADw+BDw-1 : 0] c_u;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 0;
    else if (cnt < MAX) begin
      cnt <= cnt + 1;
      if (c !== c_o) begin
        $error("Error! a * b = %d * %d = %d != golden %d", a_i, b_i, c_o, c);
        $finish;
      end
    end else if (cnt == MAX) begin
      $display("******************************");
      $display("Simulation Finsh Successfully!");
      $display("******************************");
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

  import math_pkg::*;

  mult_bw #(
    .ADw(ADw),
    .BDw(BDw),
    .MBE (MBE_IV)
  ) MULT_BW (
    .*
  );

  initial begin
    $dumpfile("sim.vcd");
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

`timescale 1ns / 1ns

module tb_rnd_sat;

  // clock
  localparam FREQ        = 1_000_000;
  localparam PERIOD      = 1_000_000_000 / FREQ;
  localparam HALF_PERIOD = PERIOD / 2;

  logic clk_i;
  logic rst_ni;

  always #(HALF_PERIOD) clk_i = ~clk_i;

  import math_pkg::*;

  // DUT parameter
  parameter InDw = 16;
  parameter OutDw = 8;
  parameter ShiftDw = 3;

  // simulation setting up
  logic                 tc_mode_i;     // two's complement; 0 = unsigned, 1 = signed
  round_mode_e          round_mode_i;  // round mode
  logic                 saturate_en_i; // satuate enable
  logic [ShiftDw-1 : 0] shift_i;       // shift amount
  logic [InDw-1 : 0]    data_i;        // data in
  logic [OutDw-1 : 0]   data_o;        // data out

  rnd_sat #(
    .InDw(InDw),
    .OutDw(OutDw),
    .ShiftDw(ShiftDw)
  ) RND_SAT (
    .*
  );

  initial begin
    $dumpfile("sim.vcd");
    $dumpvars;
    clk_i = 1;
    rst_ni = 0;
    tc_mode_i = 0;     // two's complement; 0 = unsigned, 1 = signed
    round_mode_i = DIRECT_DOWN;  // round mode
    saturate_en_i = 1; // satuate enable
    data_i = 16'b0101_1111_1010_0000;
    shift_i = 6;
    #(2*PERIOD);
    rst_ni = 1;
    #(4*PERIOD);
    $display("******************************");
    $display("Simulation Finsh Successfully!");
    $display("******************************");
    $finish;

  end

endmodule

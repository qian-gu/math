`timescale 1ns / 1ns

module tb_mult_sa;

  // clock
  localparam FREQ        = 1_000_000;
  localparam PERIOD      = 1_000_000_000 / FREQ;
  localparam HALF_PERIOD = PERIOD / 2;

  logic clk_i;
  logic rst_ni;

  always #(HALF_PERIOD) clk_i = ~clk_i;

  // DUT parameter
  parameter ADw = 8;
  parameter BDw = 4;
  parameter OptBw = 0;

  // simulation parameter
  parameter MAX = 2**(ADw+BDw);  // iterate all situation

  // simulation setting up
  logic [ADw+BDw : 0]   cnt;
  logic [1 : 0]         tc_mode_i;
  logic                 en_pi;
  logic [ADw-1 : 0]     a_i;
  logic [BDw-1 : 0]     b_i;
  logic                 c_valid_o;
  logic                 busy_o;
  logic [ADw+BDw-1 : 0] c_o;
  logic [ADw+BDw-1 : 0] c;

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
    else en_pi <= init_p | c_valid_o;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) cnt <= 0;
    else if (cnt < MAX) begin
      if (c_valid_o) begin
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
    else if (c_valid_o) a_i <= a_i + 1;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) b_i <= '0;
    else if (c_valid_o & (a_i == '1)) b_i <= b_i + 1;
  end

  mult_sa #(
    .ADw(ADw),
    .BDw(BDw),
    .OptBw(OptBw)
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

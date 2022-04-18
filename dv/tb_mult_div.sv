`timescale 1ns / 1ns

module tb_mult_div;

  // clock
  parameter FREQ = 1_000_000;

  localparam PERIOD = 1_000_000_000 / FREQ;
  localparam HALF_PERIOD = PERIOD / 2;

  logic clk_i;
  logic rst_ni;


  always #(HALF_PERIOD) clk_i = ~clk_i;

  // DUT parameter
  parameter DW = 8;

  // simulation parameter
  parameter MAX = 2**(2*DW);  // iterate all situation

  // simulation setting up
  logic [2*DW : 0]   cnt;
  logic [1 : 0]      tc_mode_i;
  logic              operator_i;
  logic              en_pi;
  logic [DW-1 : 0]   a_i;
  logic [DW-1 : 0]   b_i;
  logic              c_vld_o;
  logic              busy_o;
  logic              div_by_zero_o;
  logic              div_overflow_o;
  logic [2*DW-1 : 0] c_o;
  logic [2*DW-1 : 0] mult_c;
  logic [DW-1   : 0] quotient;
  logic [DW-1   : 0] remainder;
  logic [2*DW-1 : 0] div_c;

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
      if (operator_i == 1'b0) begin  // mult
        if (c_vld_o) begin
          cnt <= cnt + 1;
          if (mult_c !== c_o) begin
            $error("Error! a * b = %d * %d = %d != golden %d", a_i, b_i, c_o, mult_c);
            $finish;
          end
        end
      end else begin  // div
        if (c_vld_o & ~div_overflow_o) begin
          cnt <= cnt + 1;
          if (divide_by_0 ^ div_by_zero_o) begin
            $error("Error! divde-by-0 wrong!");
            $finish;
          end else if ({div_c != c_o}) begin
            $error("Error! a / b = %d / %d = %d != golden %d", a_i, b_i, c_o, div_c);
            $finish;
          end
        end
      end
    end else if (cnt == MAX) begin
      $display("******************************");
      $display("Simulation Finsh Successfully!");
      $display("******************************");
      $finish;
    end
  end

  // golden reference
  always_comb begin
    case(tc_mode_i)
      2'b00: mult_c = $unsigned(a_i) * $unsigned(b_i);
      2'b01: mult_c = $signed(a_i) * $signed({1'b0, b_i});
      2'b10: mult_c = $signed({1'b0, a_i}) * $signed(b_i);
      2'b11: mult_c = $signed(a_i) * $signed(b_i);
    endcase
  end

  logic divide_by_0;
  assign divide_by_0 = (b_i == '0);

  always_comb begin
    case(tc_mode_i)
      2'b00: begin
        if (divide_by_0) begin
          quotient = '1;
          remainder = a_i;
        end else begin
          quotient = $unsigned(a_i) / $unsigned(b_i);
          remainder = a_i - quotient * b_i;
        end
      end
      2'b01: begin
        if (divide_by_0) begin
          quotient = '1;
          remainder = a_i;
        end else begin
          quotient = $signed({a_i}) / $signed({1'b0, b_i});
          remainder = a_i - quotient * b_i;
        end
      end
      2'b10: begin
        if (divide_by_0) begin
          quotient = '1;
          remainder = a_i;
        end else begin
          quotient = $signed({1'b0, a_i}) / $signed(b_i);
          remainder = a_i - quotient * b_i;
        end
      end
      2'b11: begin
        if (divide_by_0) begin
          quotient = '1;
          remainder = a_i;
        end else begin
          quotient = $signed({a_i}) / $signed({b_i});
          remainder = a_i - quotient * b_i;
        end
      end
    endcase
  end
  assign div_c = {remainder, quotient};

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) a_i <= '0;
    else if (c_vld_o) a_i <= a_i + 1;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) b_i <= '0;
    else if (c_vld_o & (a_i == '1)) b_i <= b_i + 1;
  end

  mult_div #(
    .DW(DW)
  ) MULT_DIV (
    .*
  );

  initial begin
    $dumpfile("sim.vcd");
    $dumpvars;
    clk_i = 1;
    rst_ni = 0;
    tc_mode_i = 2'b00;
    operator_i = 1'b1;
    a_i = 0;
    b_i = 0;
    en_pi = 0;
    #(2*PERIOD);
    rst_ni = 1;

  end

endmodule

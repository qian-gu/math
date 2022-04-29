`timescale 1ns / 1ns

module tb_shifter;

  import math_pkg::*;

  // clock
  localparam FREQ        = 1_000_000;
  localparam PERIOD      = 1_000_000_000 / FREQ;
  localparam HALF_PERIOD = PERIOD / 2;

  logic clk_i;
  logic rst_ni;

  always #(HALF_PERIOD) clk_i = ~clk_i;

  // DUT parameter
  parameter Dw = 9;
  parameter Sw = $clog2(Dw);
  parameter MAX = Dw;

  logic [Dw-1 : 0] data_i;       // shift data in
  logic [Sw-1 : 0] shift_i;      // shift amount
  shift_mode_e     shift_mode_i; // shift mode: {sll, srl, sra, slb, srb}
  logic [Dw-1 : 0] data_o;       // shift out data

  // simulation setting up
  logic [Dw : 0]     cnt;
  logic [2*Dw-1 : 0] all;
  logic [Dw-1 : 0]   sll;
  logic [Dw-1 : 0]   srl;
  logic [Dw-1 : 0]   sra;
  logic [Dw-1 : 0]   slb;
  logic [Dw-1 : 0]   srb;
  logic [Dw-1 : 0]   golden;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) cnt <= 0;
    else if (cnt < MAX) begin
      if (cnt == 0) shift_i <= 'd0;
      else shift_i <= shift_i + 1'b1;
      cnt <= cnt + 1;
      if (data_o != golden) begin
        $error("Error! data_i = %d, shift_i = %d, data_o = %d != golden %d",
               data_i, shift_i, data_o, golden);
        $finish;
      end
    end else if (cnt == MAX) begin
      $display("******************************");
      $display("Simulation Finsh Successfully!");
      $display("******************************");
      $finish;
    end
  end

  // golden
  assign sll = data_i << shift_i;
  assign srl = data_i >> shift_i;
  assign sra = $signed(data_i) >>> shift_i;
  assign all = {data_i, data_i};
  always_comb begin
    case(shift_i)
      'd0: slb = all[Dw-0 +: Dw];
      'd1: slb = all[Dw-1 +: Dw];
      'd2: slb = all[Dw-2 +: Dw];
      'd3: slb = all[Dw-3 +: Dw];
      'd4: slb = all[Dw-4 +: Dw];
      'd5: slb = all[Dw-5 +: Dw];
      'd6: slb = all[Dw-6 +: Dw];
      'd7: slb = all[Dw-7 +: Dw];
      'd8: slb = all[Dw-8 +: Dw];
    endcase
  end
  always_comb begin
    case(shift_i)
      'd0: srb = all[0 +: Dw];
      'd1: srb = all[1 +: Dw];
      'd2: srb = all[2 +: Dw];
      'd3: srb = all[3 +: Dw];
      'd4: srb = all[4 +: Dw];
      'd5: srb = all[5 +: Dw];
      'd6: srb = all[6 +: Dw];
      'd7: srb = all[7 +: Dw];
      'd8: srb = all[8 +: Dw];
    endcase
  end


  always_comb begin
    case(shift_mode_i)
      SLL: golden = sll;
      SRL: golden = srl;
      SRA: golden = sra;
      SLB: golden = slb;
      SRB: golden = srb;
      default: golden = data_i;
    endcase
  end

  shifter #(
    .Dw(Dw)
    ) SHIFTER (
      .*
    );


  initial begin
    $dumpfile("sim.vcd");
    $dumpvars;
    clk_i = 1;
    rst_ni = 0;
    shift_i = 0;
    data_i = 9'h1F0;
    shift_mode_i = SRA;
    #(2*PERIOD);
    rst_ni = 1;

  end

endmodule

// tb_simple_ff_async.vhd
// ------------------------------------
// Testbench for the simple FIFO alwqays_ff
// ------------------------------------
// Author : Frank Bruno
// Show the difference (or similarities of always_ff)
`timescale 1ns/10ps
module tb_simple_init_ff;
  bit CK;
  bit CE;
  bit D;
  bit Q;

  simple_init_ff u0 (.*);

  initial begin
    CK = '0;
    forever CK = #100 ~CK;
  end

  initial begin
    CE = '0;
    D  = '0;
    repeat (5) @(posedge CK);
    D  <= '1;
    @(posedge CK);
    D  <= '0;
    @(posedge CK);
    CE <= '1;
    D  <= '1;
    @(posedge CK);
    D  <= '0;
    @(posedge CK);
    $finish;
  end
endmodule

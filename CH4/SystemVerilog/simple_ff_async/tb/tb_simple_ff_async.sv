// tb_simple_ff_async.vhd
// ------------------------------------
// Testbench for the simple FIFO Async reset
// ------------------------------------
// Author : Frank Bruno
`timescale 1ns/10ps
module tb_simple_ff_async;
  parameter ASYNC = "TRUE";
  bit CK;
  bit CE;
  bit SR;
  bit D;
  bit Q;

  simple_ff_async #(.ASYNC(ASYNC)) u0 (.D, .SR, .CE, .CK, .Q);

  initial begin
    CK = '0;
    #1000;
    forever CK = #100 ~CK;
  end

  initial begin
    CE = '0;
    D  = '0;
    #100 SR = '1;
    @(posedge CK);
    SR <= '0;
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

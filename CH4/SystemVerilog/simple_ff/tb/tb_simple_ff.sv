// tb_simple_ff.sv
// ------------------------------------
// Generate a test to lok at the simple_ff waveforms
// ------------------------------------
// Author : Frank Bruno
`timescale 1ns/10ps
module tb_simple_ff;
  bit CK;
  bit CE;
  bit D;
  bit Q;

  simple_ff u0 (.CK, .D, .Q);

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

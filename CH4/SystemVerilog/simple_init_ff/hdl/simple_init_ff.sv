// simple_init_ff.sv
// ------------------------------------
// Testbench for the simple showing always_ff
// ------------------------------------
// Author : Frank Bruno
`timescale 1ns/10ps
module simple_init_ff
  (
   input wire   CK,
   input wire   D,
   output logic Q
   );

  initial begin Q = '1; end
  always_ff @(posedge CK) Q <= D;
  //always @(posedge CK) Q <= D;

endmodule

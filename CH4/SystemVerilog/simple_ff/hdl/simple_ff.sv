// simple_ff.sv
// ------------------------------------
// Example Simple Flip Flop inference
// ------------------------------------
// Author : Frank Bruno
// Infer a simple FF
`timescale 1ns/10ps
module simple_ff
  (
   input wire   CK,
   input wire   D,
   output logic Q
   );

  always_ff @(posedge CK) Q <= D;

endmodule

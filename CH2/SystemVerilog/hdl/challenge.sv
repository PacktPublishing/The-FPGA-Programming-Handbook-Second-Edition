// challenge.sv
// ------------------------------------
// Chapter 2 Challenge Template
// ------------------------------------
// Author : Frank Bruno
// This file is a template for writing a full adder
`timescale 1ns/10ps
module challenge
  (
   input  wire  [2:0]    SW,
   output logic [1:0]    LED
   );

  // SW[2] is carry in
  // SW[1] is A
  // SW[0] is B
  assign LED[0]  = '0; // Write the code for the Sum
  assign LED[1]  = '0; // Write the code for the Carry
endmodule // challenge

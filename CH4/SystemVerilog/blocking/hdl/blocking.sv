// blocking.sv
// ------------------------------------
// Example file to show blocking assignments
// ------------------------------------
// Author : Frank Bruno
// This file demonstrates potential problems and differences between blocking
// and non blocking assignment
`timescale 1ns/10ps
module blocking
  #
  (
   parameter    BLOCK = "FALSE"
  )
  (
   input wire   CK,
   input wire   D,
   output logic Q
   );

  logic         stage;

  initial begin
    stage = '0;
    Q     = '0;
  end

  generate
    if (BLOCK == "TRUE") begin : g_BLOCK
      always @(posedge CK) begin
        stage  = D;
        Q      = stage;
      end
    end else begin : g_NONBLOCK
      always @(posedge CK) begin
        stage  <= D;
        Q      <= stage;
      end
    end
  endgenerate

endmodule

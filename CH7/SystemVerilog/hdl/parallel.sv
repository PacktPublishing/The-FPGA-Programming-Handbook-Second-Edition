// parallel.sv
// ------------------------------------
// Example parallel implmentation
// ------------------------------------
// Author : Frank Bruno
// Show an example pipelined parallel summation. This demonstrates the power of
// the FPGA to handle many operations in parallel that a processor would need
// to take many clock cycles to accomplish.
module parallel
  (
   input wire                   clk,
   input wire [255:0][31:0]     in_data,
   input wire                   in_valid,

   output logic [39:0]          out_data,
   output logic                 out_valid
   );

  logic [127:0][32:0]           int_data0;
  logic [63:0][33:0]            int_data1;
  logic [31:0][34:0]            int_data2;
  logic [15:0][35:0]            int_data3;
  logic [7:0][36:0]             int_data4;
  logic [3:0][37:0]             int_data5;
  logic [1:0][38:0]             int_data6;
  logic [6:0]                   int_valid;
  always @(posedge clk) begin
    for (int i = 0; i < 128; i++) begin
      int_data0[i] <= in_data[i*2+0] + in_data[i*2+1];
    end
    for (int i = 0; i < 64; i++) begin
      int_data1[i] <= int_data0[i*2+0] + int_data0[i*2+1];
    end
    for (int i = 0; i < 32; i++) begin
      int_data2[i] <= int_data1[i*2+0] + int_data1[i*2+1];
    end
    for (int i = 0; i < 16; i++) begin
      int_data3[i] <= int_data2[i*2+0] + int_data2[i*2+1];
    end
    for (int i = 0; i < 8; i++) begin
      int_data4[i] <= int_data3[i*2+0] + int_data3[i*2+1];
    end
    for (int i = 0; i < 4; i++) begin
      int_data5[i] <= int_data4[i*2+0] + int_data4[i*2+1];
    end
    for (int i = 0; i < 2; i++) begin
      int_data6[i] <= int_data5[i*2+0] + int_data5[i*2+1];
    end
    out_data  <= int_data6[0] + int_data6[1];
    int_valid <= int_valid << 1 | in_valid;
    out_valid <= int_valid[6];
  end // always @ (posedge clk)
endmodule // parallel

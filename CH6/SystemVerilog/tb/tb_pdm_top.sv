// tb_pdm.sv
// ------------------------------------
// Test Bench for PDM
// ------------------------------------
// Author : Frank Bruno, Guy Eschemann
// This module generates a PDM waveform and samples the same waveform.
// The outputs can be visually verfied. Please see the book for how to use it.
`timescale 1ns/10ps
module tb_pdm_top;

  parameter CLK_FREQ = 100;
  logic         clk;     // 100Mhz clock

   // Microphone interface
  logic         m_clk;
  logic         m_lr_sel;
  logic         m_data;

  logic         R, G,  B;
  logic [15:0]  LED;
  logic         BTNC, BTNU;
  tri1          AUD_PWM;
  wire          AUD_SD;

  initial clk = '0;
  always begin
    clk = #5 ~clk;
  end

  pdm_top
    #
    (
     .CLK_FREQ (CLK_FREQ)
     )
  u_pdm_input
    (
     .clk,
     .m_clk,
     .m_lr_sel,
     .m_data,
     .R,
     .G,
     .B,
     .BTNU,
     .BTNC,
     .LED,
     .AUD_PWM,
     .AUD_SD
     );

  logic [6:0] data_in;

  pdm_output u_pdm_output
    (
     .clk      (m_clk),
     .data_in  (data_in),
     .data_out (m_data)
   );

  // PDM generator
  bit [6:0] sin_table[128];

  initial begin
    sin_table = '{0:7'h01, 1:7'h01, 2:7'h03, 3:7'h04, 4:7'h06, 5:7'h07, 6:7'h09, 7:7'h0a,
                  8:7'h0c, 9:7'h0d, 10:7'h0f, 11:7'h10, 12:7'h12, 13:7'h13, 14:7'h15, 15:7'h16,
                  16:7'h18, 17:7'h19, 18:7'h1a, 19:7'h1c, 20:7'h1d, 21:7'h1f, 22:7'h20, 23:7'h21,
                  24:7'h23, 25:7'h24, 26:7'h25, 27:7'h26, 28:7'h27, 29:7'h29, 30:7'h2a, 31:7'h2b,
                  32:7'h2c, 33:7'h2d, 34:7'h2e, 35:7'h2f, 36:7'h30, 37:7'h31, 38:7'h32, 39:7'h33,
                  40:7'h34, 41:7'h35, 42:7'h36, 43:7'h36, 44:7'h37, 45:7'h38, 46:7'h38, 47:7'h39,
                  48:7'h3a, 49:7'h3a, 50:7'h3b, 51:7'h3b, 52:7'h3c, 53:7'h3c, 54:7'h3d, 55:7'h3d,
                  56:7'h3d, 57:7'h3e, 58:7'h3e, 59:7'h3e, 60:7'h3e, 61:7'h3e, 62:7'h3e, 63:7'h3e,
                  64:7'h3f, 65:7'h3e, 66:7'h3e, 67:7'h3e, 68:7'h3e, 69:7'h3e, 70:7'h3e, 71:7'h3e,
                  72:7'h3d, 73:7'h3d, 74:7'h3d, 75:7'h3c, 76:7'h3c, 77:7'h3b, 78:7'h3b, 79:7'h3a,
                  80:7'h3a, 81:7'h39, 82:7'h38, 83:7'h38, 84:7'h37, 85:7'h36, 86:7'h36, 87:7'h35,
                  88:7'h34, 89:7'h33, 90:7'h32, 91:7'h31, 92:7'h30, 93:7'h2f, 94:7'h2e, 95:7'h2d,
                  96:7'h2c, 97:7'h2b, 98:7'h2a, 99:7'h29, 100:7'h27, 101:7'h26, 102:7'h25, 103:7'h24,
                  104:7'h23, 105:7'h21, 106:7'h20, 107:7'h1f, 108:7'h1d, 109:7'h1c, 110:7'h1a, 111:7'h19,
                  112:7'h18, 113:7'h16, 114:7'h15, 115:7'h13, 116:7'h12, 117:7'h10, 118:7'h0f, 119:7'h0d,
                  120:7'h0c, 121:7'h0a, 122:7'h09, 123:7'h07, 124:7'h06, 125:7'h04, 126:7'h03, 127:7'h01};
  end

  bit [7:0] counter;
  bit [6:0] int_count;

  initial begin
    int_count       = '0;
    counter         = '0;
    data_in         = '0;
    BTNC            = '0;
    BTNU            = '0;
    repeat (10000) @(posedge clk);
    BTNC = '1;
    repeat (100) @(posedge clk);
    BTNC = '0;
    while (~&LED) repeat (100) @(posedge clk);
    // Add a delay to wait for the entire data capture to complete, 42ms
    repeat (4200000) @(posedge clk);
    BTNU = '1;
    repeat (100) @(posedge clk);
    BTNU = '0;
    while (|LED) repeat (100) @(posedge clk);
    repeat (100000) @(posedge clk);
    $display("Waveform has been sampled and played back. You can view waves.");
    $stop;
  end

  always @(posedge m_clk) begin
    int_count <= int_count + 1'b1;
    if (&int_count) counter <= counter + 1'b1;
    if (counter > 127) begin
      data_in <= 64+sin_table[counter[6:0]];
    end else begin
      data_in <= 64-sin_table[counter[6:0]];
    end
  end

endmodule

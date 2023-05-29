// uart_top.vhd
// ------------------------------------
// UART top level
// ------------------------------------
// Author : Frank Bruno
`timescale 1ns/10ps
module uart_top
  #
  (
   parameter NUM_SEGMENTS = 8,
   parameter USE_PLL      = "FALSE"
   )
  (
   input wire                         clk,

   output logic [NUM_SEGMENTS-1:0]    anode,
   output logic [7:0]                 cathode,

   // UART
   input                              uart_ctsn , // Clear to send
   input                              uart_rx,   // RX pin
   output                             uart_rtsn, // Request to send
   output                             uart_tx    // TX pin
   );

  logic [7:0][3:0]                    encoded;
  logic [NUM_SEGMENTS-1:0]            digit_point;

  logic                               clk_50;

  sys_pll u_sys_pll
    (
     .clk_out1     (clk_50),
     .clk_in1      (clk)
     );

  assign digit_point = '1;

  seven_segment
    #
    (
     .NUM_SEGMENTS (NUM_SEGMENTS),
     .CLK_PER      (20)
     )
  u_seven_segment
    (
     .clk          (clk_50),
     .encoded      (encoded),
     .digit_point  (digit_point),
     .anode        (anode),
     .cathode      (cathode)
     );

  logic       cpu_int; // interrupt
  logic       reg_awvalid;
  logic       reg_awready;
  logic [2:0] reg_awaddr;

  logic       reg_wvalid;
  logic       reg_wready;
  logic [7:0] reg_wdata;

  logic       reg_bready;
  logic       reg_bvalid;
  logic [1:0] reg_bresp;

  logic       reg_arvalid;
  logic       reg_arready;
  logic [2:0] reg_araddr;

  logic       reg_rready;
  logic       reg_rvalid;
  logic [7:0] reg_rdata;
  logic [1:0] reg_rresp;

  // UART
  uart u_uart
    (
     // Utility signals
     .sys_clk      (clk_50),
     .sys_rstn     ('1),

     .*
     );

  assign reg_bready = '1;
  assign reg_rready = '1;

  (*mark_debug = "true"*)enum        {IDLE, W4DATA, RDDATA} uart_cs = IDLE;

  // The UART is setup to be 5600bps 8-n-1, so we won't configure it here.
  // We'll just poll data when the RX is ready and display on the 7 segment display.
  always @(posedge clk_50) begin
    reg_arvalid <= '0;
    case (uart_cs)
      IDLE: begin
        reg_arvalid <= '1;
        reg_araddr  <= 3'h5; // Check if RX data is available
        uart_cs     <= W4DATA;
      end
      W4DATA: begin
        if (reg_rvalid && reg_rdata[0]) begin
          // Read RX Register
          reg_arvalid <= '1;
          reg_araddr  <= 3'h0; // Check if RX data is available
          uart_cs     <= RDDATA;
        end else if (reg_rvalid) begin
          uart_cs     <= IDLE;
        end
      end
      RDDATA: begin
        if (reg_rvalid) begin
          encoded[0] <= reg_rdata[3:0];
          encoded[1] <= reg_rdata[7:4];
          for (int i = 2; i < 8; i++) begin
            encoded[i] <= encoded[i-2];
          end
          uart_cs  <= IDLE;
        end
      end
    endcase // case (uart_cs)
  end // always @ (posedge clk)

endmodule // uart_top

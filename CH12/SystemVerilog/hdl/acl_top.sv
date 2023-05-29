// acl_top.vhd
// ------------------------------------
// Top level of connection to ACL
// ------------------------------------
// Author : Frank Bruno
`timescale 1ns/10ps
module acl_top
  #
  (
   parameter NUM_SEGMENTS = 8,
   parameter USE_PLL      = "FALSE"
   )
  (
   input wire                      clk,
   input wire                      CPU_RESETN,

   output logic [NUM_SEGMENTS-1:0] anode,
   output logic [7:0]              cathode,

   // SPI Port
   input                           int1, // Interrupt 1
   input                           int2, // Interrupt 2
   output                          CSn, // Chip select to ACL
   output                          SCLK, // Clock to ACL chip
   output                          MOSI, // Data to ACL chip
   input                           MISO  // Data from ACL chip
   );

  logic [7:0][3:0]                    encoded;
  logic [NUM_SEGMENTS-1:0]            digit_point;
  (*async_reg = "true"*) logic [1:0]  rst;

  assign digit_point = '1;

  seven_segment
    #
    (
     .NUM_SEGMENTS (NUM_SEGMENTS),
     .CLK_PER      (20)
     )
  u_seven_segment
    (
     .clk          (clk),
     .encoded      (encoded),
     .digit_point  (digit_point),
     .anode        (anode),
     .cathode      (cathode)
     );

  (*mark_debug = "true"*)logic       reg_awvalid = '0;
  (*mark_debug = "true"*)logic       reg_awready;
  (*mark_debug = "true"*)logic [5:0] reg_awaddr;

  (*mark_debug = "true"*)logic       reg_wvalid = '0;
  (*mark_debug = "true"*)logic       reg_wready;
  (*mark_debug = "true"*)logic [7:0] reg_wdata;

  logic       reg_bready;
  logic       reg_bvalid;
  logic [1:0] reg_bresp;

  (*mark_debug = "true"*)logic       reg_arvalid = '0;
  (*mark_debug = "true"*)logic       reg_arready;
  (*mark_debug = "true"*)logic [5:0] reg_araddr;

  (*mark_debug = "true"*)logic       reg_rready;
  (*mark_debug = "true"*)logic       reg_rvalid;
  (*mark_debug = "true"*)logic [7:0] reg_rdata;
  logic [1:0] reg_rresp;
  logic [15:0] wait_time = '0;

  // UART
  spi u_spi
    (
     // Utility signals
     .sys_clk      (clk),
     .sys_rst      (rst[1]),

     .*
     );

  assign reg_bready = '1;
  assign reg_rready = '1;

  (*mark_debug = "true"*)enum bit [4:0]       {IDLE, S[10]} spi_cs = IDLE;

  // The UART is setup to be 5600bps 8-n-1, so we won't configure it here.
  // We'll just poll data when the RX is ready and display on the 7 segment display.
  always @(posedge clk) begin
    rst[1] <= rst[0];
    rst[0] <= ~CPU_RESETN;
    reg_arvalid <= '0;
    case (spi_cs)
      IDLE: begin
        wait_time <= wait_time + 1'b1;
        if (&wait_time) spi_cs <= S0;
      end
      S0: begin
        reg_awvalid <= '1;
        reg_awaddr  <= 6'h27;
        reg_wvalid  <= '1;
        reg_wdata   <= 8'h00;
        spi_cs      <= S1;
      end
      S1: begin
        if (reg_wready) begin
          reg_awvalid <= '1;
          reg_awaddr  <= 6'h2D;
          reg_wvalid  <= '1;
          reg_wdata   <= 8'h02;
          spi_cs      <= S3;
        end
      end
      S3: begin
        if (reg_wready) begin
          reg_awvalid <= '0;
          reg_wvalid  <= '0;
          spi_cs      <= S4;
        end
      end
      S4: begin
        reg_arvalid <= '1;
        //reg_araddr  <= 6'h0E;
        reg_araddr  <= 6'h08;
        if (reg_arready) spi_cs <= S5;
      end
      S5: begin
        if (reg_rready) begin
          encoded[0] <= reg_rdata[3:0];
          encoded[1] <= reg_rdata[7:4];
          spi_cs <= S6;
        end
      end
      S6: begin
        reg_arvalid <= '1;
        //reg_araddr  <= 6'h0F;
        reg_araddr  <= 6'h09;
        if (reg_arready) spi_cs <= S7;
      end
      S7: begin
        if (reg_rready) begin
          encoded[2] <= reg_rdata[3:0];
          encoded[3] <= reg_rdata[7:4];
          spi_cs <= S8;
        end
      end
      S8: begin
        reg_arvalid <= '1;
        //reg_araddr  <= 6'h10;
        reg_araddr  <= 6'h0A;
        if (reg_arready) spi_cs <= S9;
      end
      S9: begin
        if (reg_rready) begin
          encoded[4] <= reg_rdata[3:0];
          encoded[5] <= reg_rdata[7:4];
          spi_cs <= S4;
        end
      end
    endcase // case (spi_cs)

    if (rst[1]) begin
      spi_cs      <= IDLE;
      reg_awvalid <= '0;
      reg_wvalid  <= '0;
      reg_arvalid <= '0;
    end
  end // always @ (posedge clk_50)

endmodule // uart_top

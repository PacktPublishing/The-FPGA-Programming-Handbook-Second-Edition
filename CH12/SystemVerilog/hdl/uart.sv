///////////////////////////////////////////////////////////////////////////////
//
//  Copyright (C) 2014 Francis Bruno, All Rights Reserved
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, see <http://www.gnu.org/licenses>.
//
//  This code is available under licenses for commercial use. Please contact
//  Francis Bruno for more information.
//
//  http://www.gplgpu.com
//  http://www.asicsolutions.com
//
//  Title       :  Simple UART
//  File        :  uart.v
//  Author      :  Frank Bruno
//  Created     :  28-May-2015
//  RCS File    :  $Source:$
//  Status      :  $Id:$
//
//
///////////////////////////////////////////////////////////////////////////////
//
//  Description :
//  Top level of simple UART core
//
//////////////////////////////////////////////////////////////////////////////
//
//  Modules Instantiated:
//
///////////////////////////////////////////////////////////////////////////////
//
//  Modification History:
//
//  $Log:$
//
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 10ps

module uart
  (
   // Utility signals
   input wire         sys_clk, // 100 Mhz for this example
   input wire         sys_rstn, // Active low reset

   // CPU interface
   output logic       cpu_int, // interrupt
   input wire         reg_awvalid,
   output logic       reg_awready,
   input wire [2:0]   reg_awaddr,

   input wire         reg_wvalid,
   output logic       reg_wready,
   input wire [7:0]   reg_wdata,

   input wire         reg_bready,
   output logic       reg_bvalid,
   output logic [1:0] reg_bresp,

   input wire         reg_arvalid,
   output logic       reg_arready,
   input wire [2:0]   reg_araddr,

   input wire         reg_rready,
   output logic       reg_rvalid,
   output logic [7:0] reg_rdata,
   output logic [1:0] reg_rresp,

   // External pins
   input              uart_ctsn, // Clear to send
   input              uart_rx, // RX pin
   output             uart_rtsn, // Request to send
   output             uart_tx   // TX pin
   );

  typedef enum bit [1:0]
               {
                TX_IDLE       = 2'h0,
                TX_START      = 2'h1,
                TX_WAIT       = 2'h2,
                TX_TX         = 2'h3} tx_t;

  typedef enum bit [1:0]
               {
                RX_IDLE       = 2'h0,
                RX_START      = 2'h1,
                RX_SHIFT      = 2'h2,
                RX_PUSH       = 2'h3} rx_t;

  (* mark_debug = "true" *)rx_t                 rx_sm;
  tx_t                 tx_sm;

  logic [17:0]         tx_clken_count;// Counter to generate the clock enables
  (* mark_debug = "true" *)logic [17:0]         rx_clken_count;// Counter to generate the clock enables
  logic                tx_baudclk_en; // Enable to simulate the baud clock
  (* mark_debug = "true" *)logic                rx_baudclk_en; // Enable to simulate the baud clock
  logic [2:0]          tx_clk_cnt;    // Track # of sub baud clocks
  logic [3:0]          tx_data_cnt;   // Data counter
  (* mark_debug = "true" *)logic [2:0]          rx_clk_cnt;    // Track # of sub baud clocks
  (* mark_debug = "true" *)logic [4:0]          rx_data_cnt;   // Data counter
  (* mark_debug = "true" *)logic [6:0]          rx_data_shift; // Shift 7 pieces of data for voting

  wire                 tx_data_avail; // Transmit data is available
  logic                tx_fifo_pop;   // Pop TX data
  logic [10:0]         tx_shift;      // TX shift register
  (* mark_debug = "true" *)logic [10:0]         rx_shift;      // TX shift register
  wire [7:0]           tx_fifo_dout;  // Data for TX
  wire [2:0]           parity;        // Parity selection
  wire                 force_rts;     //
  wire                 autoflow;      // Automatically generate flow control
  wire                 loopback;      // Loopback mode
  logic                tx_rtsn;       // Generate the RTSn for tx
  logic [2:0]          din_shift;     // Shift the 7 bits of data for voting
  wire                 rx_fifo_full;  // We can't accept RX
  (* mark_debug = "true" *) logic [6:0]          uart_rxd;      // delayed RX data
  logic                rx_parity_err; // Parity Errror on Receive
  logic                rx_frame_err;  // Framing error (missing stop bit)
  (* mark_debug = "true" *) logic                rx_fifo_push;  // Piush receive data into FIFO
  (* mark_debug = "true" *) logic [7:0]          rx_fifo_din;   // RX data into receive FIFO
  logic                vote_bit;      // Vote on the current bit
  logic                voted;         // for testing to see if we have mismatch
  (* mark_debug = "true" *)wire [15:0]          baud_terminal_count;
  wire                 baud_reset;    // When terminal count values change, reset count
  logic                tx_shift_empty;// TX shift register empty for status
  logic                enable_tx;     // Force a '1' or break when not enabled
  wire                 int_rx;
  (* mark_debug = "true" *)logic                rx_baud_reset; // Reset RX baud clock to resync

  always @(posedge sys_clk) begin
    tx_baudclk_en <= '0;
    rx_baudclk_en <= '0;

    if (tx_clken_count == {1'b0, baud_terminal_count[15:1]}) begin
      tx_baudclk_en <= '1;
      tx_clken_count <= '0;
    end else
      tx_clken_count <= tx_clken_count + 1'b1;

    //if (rx_clken_count == {1'b0,baud_terminal_count[15:1], 1'b0}) begin
    if (rx_clken_count == {2'b0,baud_terminal_count[15:2]}) begin
      rx_baudclk_en <= '1;
      rx_clken_count <= rx_clken_count + 1'b1;
    end else if (rx_clken_count == {1'b0, baud_terminal_count[15:1]}) begin
      //rx_baudclk_en <= '1;
      rx_clken_count <= 16'h0;
    end else
      rx_clken_count <= rx_clken_count + 1'b1;

    // Synchronous reset
    // Asynchronous resets with large fanouts can cause the use of clock
    // trees in FPGAs.
    // Putting the reset clause at the top for a synchronous reset can
    // Cause hold logic to be implemented during reset for signals not in
    // the clause. Puttinf the clause below means we only need to reset
    // essential signals.
    if (~sys_rstn | baud_reset) begin
      tx_clken_count <= '0;
      tx_baudclk_en  <= '0;
    end
    if (~sys_rstn | baud_reset | rx_baud_reset) begin
      rx_clken_count <= '0;
      rx_baudclk_en  <= '0;
    end
  end // always @ (posedge sys_clk)

  uart_cpu u_cpu
    (
     // Utility signals
     .sys_clk             (sys_clk),
     .sys_rstn            (sys_rstn),
     .baud_en             (tx_baudclk_en),

     // CPU interface
     .cpu_int             (cpu_int),
     .reg_awvalid         (reg_awvalid),
     .reg_awready         (reg_awready),
     .reg_awaddr          (reg_awaddr),

     .reg_wvalid          (reg_wvalid),
     .reg_wready          (reg_wready),
     .reg_wdata           (reg_wdata),

     .reg_bready          (reg_bready),
     .reg_bvalid          (reg_bvalid),
     .reg_bresp           (reg_bresp),

     .reg_arvalid         (reg_arvalid),
     .reg_arready         (reg_arready),
     .reg_araddr          (reg_araddr),

     .reg_rready          (reg_rready),
     .reg_rvalid          (reg_rvalid),
     .reg_rdata           (reg_rdata),
     .reg_rresp           (reg_rresp),

     // Registers to design
     .baud_terminal_count (baud_terminal_count),
     .baud_reset          (baud_reset),
     .rx_break_det        ('0), // fixme!
     .parity              (parity),
     .force_rts           (force_rts),
     .autoflow            (autoflow),
     .loopback            (loopback),

     // RX interface
     .rx_fifo_push        (rx_fifo_push),
     .rx_fifo_din         (rx_fifo_din),
     .rx_parity_err       (rx_parity_err),
     .rx_frame_err        (rx_frame_err),
     .rx_fifo_full        (rx_fifo_full),

     // TX interface
     .tx_fifo_pop         (tx_fifo_pop),
     .tx_shift_empty      (tx_shift_empty),
     .tx_data_avail       (tx_data_avail),
     .tx_fifo_dout        (tx_fifo_dout),

     // External pins
     .uart_cts            (uart_ctsn) // polarity doesn't matter. for change
     );

  // Request to send
`ifdef OLD_RTS
  // From what I found, it seems the original RTS/CTS only protected the
  // TX direction.
  assign uart_rtsn = autoflow ? tx_rtsn : !force_rts;
`else
  // I found information on using RTS to mean "do not send to me"
  assign uart_rtsn = autoflow ? rx_fifo_full : !force_rts;
`endif

  // Fixme!!!! do we need to handle this differently for each RTS type?
  assign tx_ctsn = loopback ? uart_rtsn : uart_ctsn; // pass in the ctsn
  assign int_rx  = loopback ? uart_tx : uart_rx;

  // Fixme!!!! Do we add break?
  assign uart_tx = enable_tx ? tx_shift[0] : '1;

  always @* begin
    case (rx_data_shift[4:2])
      3'b000: vote_bit = '0;
      3'b001: vote_bit = '0;
      3'b010: vote_bit = '0;
      3'b011: vote_bit = '1;
      3'b100: vote_bit = '0;
      3'b101: vote_bit = '1;
      3'b110: vote_bit = '1;
      3'b111: vote_bit = '1;
    endcase // case (rx_data_shift[4:2])
  end // always @ *

  // UART Data State Machines
  always @(posedge sys_clk) begin
    enable_tx   <= '0;
    tx_fifo_pop <= '0;
    case (tx_sm)
      TX_IDLE: begin
        tx_shift_empty <= '1;
        tx_rtsn <= '1; // default to no TX
        if (tx_data_avail) begin
          tx_sm       <= TX_START;
          tx_fifo_pop <= '1;
        end
      end
      TX_START: begin
        tx_shift_empty <= '0;
        casex (parity)
          3'bxx0: tx_shift <= {2'b11,tx_fifo_dout,1'b0}; // No parity
          3'b001: tx_shift <= {1'b1, ~^tx_fifo_dout,
                               tx_fifo_dout,1'b0}; // Odd parity
          3'b011: tx_shift <= {1'b1,  ^tx_fifo_dout,
                               tx_fifo_dout,1'b0}; // Even parity
          3'b101: tx_shift <= {2'b11,tx_fifo_dout,1'b0}; // Force 1 parity
          3'b111: tx_shift <= {2'b10,tx_fifo_dout,1'b0}; // Force 0 parity
        endcase // casex (parity)
        tx_clk_cnt  <= '0;
        tx_data_cnt <= '0;
        tx_rtsn     <= '0;
        tx_sm       <= TX_WAIT;
      end // case: TX_IDLE
      TX_WAIT: begin
        if (tx_baudclk_en && !tx_ctsn) begin
          enable_tx <= '1;
          tx_sm <= TX_TX;
          //tx_clk_cnt <= tx_clk_cnt + 1; // count to 7
        end
      end
      TX_TX: begin
        enable_tx <= '1;
        if (tx_baudclk_en) begin
          tx_clk_cnt <= tx_clk_cnt + 1'b1; // count to 7
          if (tx_clk_cnt == 6) begin
            tx_clk_cnt  <= 3'b0;
            if (( parity[0] && (tx_data_cnt != 10)) ||
                (~parity[0] && (tx_data_cnt != 9))) begin
              tx_data_cnt <= tx_data_cnt + 1'b1;
              tx_shift    <= tx_shift >> 1;
            end else begin
              tx_data_cnt <= 4'b0;
              tx_sm       <= TX_IDLE;
            end
          end // if (tx_clk_cnt == 6)
        end // if (baudclk_en)
      end // case: TX_TX
    endcase // case (tx_sm)

    // Provide some noise rejection and
    uart_rxd <= (uart_rxd << 1) | int_rx; // Delay to look for start bit
    rx_fifo_push <= '0;
    rx_baud_reset <= '0;

    case (rx_sm)
      RX_IDLE: begin
        rx_clk_cnt  <= '0;
        rx_data_cnt <= '0;
        // Constantly watch for Start transition
        if (uart_rxd == 7'b1000000) begin
          rx_baud_reset <= '1;
          rx_data_shift <= (rx_data_shift << 1) | '0;
          rx_sm         <= RX_START;
        end
      end
      RX_START: begin
        // Verify we really detected a start bit
        if (rx_baudclk_en) begin
          // Take shifted data since clock is offset by this amount
          rx_data_shift <= (rx_data_shift << 1) | uart_rxd[6];
          rx_clk_cnt    <= rx_clk_cnt + 1'b1;
          if (rx_clk_cnt == 4) begin
            voted <= ~(&rx_data_shift[4:2] | ~|rx_data_shift[4:2]);
            rx_shift[rx_data_cnt] <= vote_bit;
            if (~vote_bit) begin
              // We did get a stop bit
              rx_data_cnt <= rx_data_cnt + 1'b1;
              rx_sm <= RX_SHIFT;
            end else begin
              // We had a false detect, go back to idle
              rx_sm <= RX_IDLE;
            end
          end
        end
      end // case: RX_START
      RX_SHIFT: begin
        // Bail out after the stop bit captured
        if (( parity[0] && (rx_data_cnt == 11)) ||
            (~parity[0] && (rx_data_cnt == 10))) begin
          // Vote and push into storage register
          rx_data_shift <= (rx_data_shift << 1) | uart_rxd[6];
          rx_clk_cnt    <= rx_clk_cnt + 1'b1;
          rx_data_cnt   <= 4'b0;
          rx_sm         <= RX_PUSH;
        end
        if (rx_baudclk_en) begin
          // Take shifted data since clock is offset by this amount
          rx_data_shift <= (rx_data_shift << 1) | uart_rxd[6];
          rx_clk_cnt    <= rx_clk_cnt + 1'b1;
          if (rx_clk_cnt == 4) begin
            voted <= ~(&rx_data_shift[4:2] | ~|rx_data_shift[4:2]);
            rx_shift[rx_data_cnt] <= vote_bit;
            // Bail out after the stop bit captured
            if (( parity[0] && (rx_data_cnt != 11)) ||
                (~parity[0] && (rx_data_cnt != 10))) begin
              rx_data_cnt <= rx_data_cnt + 1'b1;
            end else begin
              // Vote and push into storage register
              rx_data_cnt <= 4'b0;
              rx_sm       <= RX_PUSH;
            end
          end else if (rx_clk_cnt == 6) begin
            rx_clk_cnt  <= 3'b0;
          end // if (tx_clk_cnt == 6)
        end
      end // case: RX_DATA_SHIFT
      RX_PUSH: begin
        // Done w/ receive, push data into the RX fifo, detect error
        // conditions
        rx_fifo_din <= rx_shift[8:1];
        if (~parity[0])
          rx_frame_err <= ~rx_shift[9];
        else
          rx_frame_err <= ~rx_shift[10];
        casex (parity)
          3'bxx0: rx_parity_err <= '0; // No parity, no error
          3'b001: rx_parity_err <= ~^rx_shift[9:1]; // Odd Parity
          3'b011: rx_parity_err <=  ^rx_shift[9:1]; // Even Parity
          3'b101: rx_parity_err <= ~^rx_shift[9:1]; // Force 1 Parity
          3'b111: rx_parity_err <= ~^rx_shift[9:1]; // Force 0 Parity
          endcase // casex (parity)
        rx_fifo_push <= '1;
        rx_sm        <= RX_IDLE;
      end // if (rx_baudclk_en)
    endcase // case (rx_sm)

    if (~sys_rstn) begin
      tx_sm        <= TX_IDLE;
      rx_sm        <= RX_IDLE;
      tx_fifo_pop  <= '0;
      enable_tx    <= '0;
      rx_fifo_push <= '0;
      rx_baud_reset<= '0;
    end
  end
endmodule // uart

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
//  Title       :  Simple UART CPU interface
//  File        :  uart_cpu.v
//  Author      :  Frank Bruno
//  Created     :  28-May-2015
//  RCS File    :  $Source:$
//  Status      :  $Id:$
//
//
///////////////////////////////////////////////////////////////////////////////
//
//  Description :
//  CPU interface for simple UART core
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

module uart_cpu
  (
   // Utility signals
   input               sys_clk, // 100 Mhz for this example
   input               sys_rstn, // Active low reset
   input               baud_en, // Enable for the baud clock

   // CPU interface
   output logic        cpu_int, // interrupt
   input wire          reg_awvalid,
   output logic        reg_awready,
   input wire [2:0]    reg_awaddr,

   input wire          reg_wvalid,
   output logic        reg_wready,
   input wire [7:0]    reg_wdata,

   input wire          reg_bready,
   output logic        reg_bvalid,
   output logic [1:0]  reg_bresp,

   input wire          reg_arvalid,
   output logic        reg_arready,
   input wire [2:0]    reg_araddr,

   input wire          reg_rready,
   output logic        reg_rvalid,
   output logic [7:0]  reg_rdata,
   output logic [1:0]  reg_rresp,

   // Registers to design
   output logic [15:0] baud_terminal_count, // Terminal count for baud en
   output logic [2:0]  parity, // Parity setting
   output logic        force_rts, // Force RTS value for testing
   output logic        autoflow, // Generate RTS/ CTS automatically
   output logic        loopback, // Loopback for test
   output logic        baud_reset, // Reset baud rate counter

   // RX interface
   input               rx_fifo_push, // Push data from RX interface
   input [7:0]         rx_fifo_din, // Data from RX interface
   input               rx_break_det, // Detect break (not implemented)
   input               rx_parity_err, // Parity error flag on RX
   input               rx_frame_err, // Stop bit not valid
   output              rx_fifo_full, // FIFO Full

   // TX interface
   input               tx_fifo_pop, // Pop TX data for sending
   input               tx_shift_empty, // TX shift register is empty
   output              tx_data_avail, // ~tx_fifo_empty
   output [7:0]        tx_fifo_dout, // Fifo data for TX

   // External pins
   input               uart_cts // Clear to send
   );

  typedef enum         bit [2:0]
                       {
                        REG_IDLE,
                        REG_W4ADDR,
                        REG_W4DATA,
                        REG_BRESP,
                        REG_W4RDREADY
                        } reg_cs_t;

  (* mark_debug = "true" *) reg_cs_t reg_cs;

  localparam
    // mapped to 16550a registers
    RBR_THR    = 4'h0, // RX Register, TX Register - DLL LSB
    IER_IER    = 4'h1, // Interrupt Enable Register
    IIR_FCR0   = 4'h2, // interrupt ID register, FIFO control register
    LCR0       = 4'h3, // Line Control Register
    MCR0       = 4'h4, // Line Control Register
    LSR0       = 4'h5, // Line Status Register
    MSR0       = 4'h6, // Modem Status Register
    SCR0       = 4'h7, // Scratch register
    DLL        = 4'h8, // Divisor LSB
    DLM        = 4'h9, // Divisor MSB
    // These registers set the baud rate:
    // Baud    BAUDCNT_HI BAUDCNT_LO   %ERR
    // 300     8'hB9      8'hFF      -0.006382%
    // 1200    8'h2E      8'h7F      -0.006325%
    // 2400    8'h17      8'h3F      -0.00625%
    // 4800    8'h0B      8'h9F      -0.0061%
    // 9600    8'h05      8'hCF      -0.0058%
    // 14400   8'h03      8'hDF      -0.0055%
    // 19200   8'h02      8'hE7      -0.0052%
    // 28800   8'h01      8'hEF      -0.0046%
    // 38400   8'h01      8'h73      -0.004%
    // 57600   8'h00      8'hF7      -0.0028%
    IIR_FCR1   = 4'hA, // interrupt ID register, FIFO control register
    LCR1       = 4'hB, // Line Control Register
    MCR1       = 4'hC, // Modem Control Register
    LSR1       = 4'hD, // Line Status Register
    MSR1       = 4'hE, // Modem Status Register
    SCR1       = 4'hF; // Scratch register
  localparam AXI4_OKAY              = 2'b00;
  localparam AXI4_SLVERR            = 2'b10;

  logic [2:0]          reg_addr;
  logic                reg_we;
  logic [7:0]          reg_din;

  logic                dlab;               // register selector
  logic                break_en;           // Enable break
  logic                fifo_enable;        // Enable the FIFOs
  logic                reset_rx_fifo;      // Reset RX FIFO
  logic                reset_tx_fifo;      // Reset TX FIFO
  logic [7:0]          scratch_reg;        // For backward compatibility
  logic                cts_change;         // CTS has changed
  logic                cts_last;           // last CTS value

  (* mark_debug = "true" *) wire [7:0]           rx_fifo_out;        // Data from the FIFO
  (* mark_debug = "true" *) logic                rx_fifo_pop;        // Pop data from the RX fifo
  (* mark_debug = "true" *) wire                 rx_fifo_empty;      // FIFO empty
  (* mark_debug = "true" *) wire                 rx_data_avail;      // ~fifo empty
  logic [3:0]          rx_fifo_count;      // {full, count[2:0]}
  logic [2:0]          rx_thresh;          // Low watermark

  // Interrupt enables
  logic                en_rx_data_avail;   // ~fifo empty
  logic                en_tx_fifo_empty;   //
  logic                en_rx_status_change;
  logic                en_msr_change;

  wire                 tx_fifo_empty;
  logic                rx_status_change;
  logic                msr_change;
  logic                thr_empty, tx_shift_empty_d;
  logic [2:0]          int_status;    // For interrupt readback
  //Bits 1 and 2	Bit 2	Bit 1
  //0	0	Modem Status Interrupt (lowest)
  //0	1	Transmitter Holding Register Empty Interrupt
  //1	0	Received Data Available Interrupt
  //1	1	Receiver Line Status Interrupt (higest)
  wire                 char_timeout = 0; // fixme!!!
  wire                 frame_err;     // Capture the framing error

  logic                tx_fifo_push;  // Push data into TX FIFO
  logic [7:0]          tx_fifo_din;   // Registered data into FIFO
  //

  wire                 break_det;     // Break Interrupt
  logic                overrun_error; // write to full RX fifo
  wire                 parity_err;
  wire                 rx_fifo_error;

  initial begin
    reg_cs              = REG_IDLE;
    thr_empty           = 1'b0;
    dlab                = 1'b0;
    break_en            = 1'b0;
    parity              = 3'h0;
    autoflow            = 1'b0;
    loopback            = 1'b0;
    force_rts           = 1'b0;
    fifo_enable         = 1'b1;
    reset_rx_fifo       = 1'b0;
    reset_tx_fifo       = 1'b0;
    rx_thresh           = '0; //2'h1; // Default to depth of 1 to signal data ready
    en_rx_data_avail    = 1'b0;
    en_tx_fifo_empty    = 1'b0;
    en_rx_status_change = 1'b0;
    en_msr_change       = 1'b0;
    tx_fifo_push        = 1'b0;
    overrun_error       = 1'b0;
    baud_terminal_count = 16'd247; // 57600
  end

  always @(posedge sys_clk) begin

    // defaults
    rx_fifo_pop   <= '0;
    reg_we        <= '0;
    reg_bvalid    <= '0;
    baud_reset    <= '0;
    reg_rresp     <= AXI4_OKAY; // Okay

    // Detect a change in CTS status
    cts_last <= uart_cts;
    if (baud_en & (cts_last ^ uart_cts)) cts_change <= 1'b1;

    case (reg_cs)
      REG_IDLE: begin
        reg_arready <= '1;
        reg_awready <= '1;
        reg_wready  <= '1;
        reg_rvalid  <= '0;
        if (reg_arvalid) begin
          reg_rvalid  <= '1;
          if (~reg_rready) begin
            reg_arready <= '0;
            reg_cs      <= REG_W4RDREADY;
          end

          // Read bus
          case ({dlab, reg_araddr})
            // RX Buffer Register, TX Holding Register
            RBR_THR: begin
              reg_rdata     <=  rx_fifo_out[7:0];
              rx_fifo_pop   <= ~rx_fifo_empty;
              if (~reg_rready) begin
                reg_arready <= '0;
                reg_cs      <= REG_W4RDREADY;
              end
            end
            IER_IER: begin
              reg_rdata <= {4'h0, // Don't support lp modes or sleep
                            en_rx_data_avail,
                            en_tx_fifo_empty,
                            en_rx_status_change,
                            en_msr_change};
            end
            IIR_FCR0, IIR_FCR1: begin
              thr_empty      <= '0; // reset status bit
              reg_rdata[7:6] <= {2{fifo_enable}};
              reg_rdata[5:4] <= 2'b00;
              reg_rdata[3:0] <= {int_status, cpu_int};
            end
            LCR0, LCR1: begin
              reg_rdata <= {dlab,     // 1 = select config registers, 0 = normal
                            break_en, // Enable break signal (not currently used)
                            parity,   /* Parity setting
                                       * [5:3]    Setting
                                       *  xx0     No Parity
                                       *  001     Odd Parity
                                       *  011     Even Parity
                                       *  101     High Parity (stick)
                                       *  111     Low Parity (stick)
                                       */
                            1'b0,     // Unused (not requested)
                            2'h0};    // Unused since we are forcing 8 bit data
            end // case: LCR0, LCR1
            MCR0, MCR1: begin
              reg_rdata <= {2'b0,       // Reserved
                            autoflow,   // Generate RTS automatically
                            loopback,   // Loopback mode
                            2'b0,       // AUX unused
                            force_rts,  // RTS
                            1'b0};      // DTR unused
            end
            LSR0, LSR1: begin
              reg_rdata <= {rx_fifo_error & ~rx_fifo_empty, // Error in Received FIFO (br, par, fr)
                            tx_shift_empty,  // Empty Data Holding Registers
                            tx_fifo_empty, // Empty Transmitter Holding Register
                            break_det & ~rx_fifo_empty, // Break Interrupt
                            frame_err & ~rx_fifo_empty, // Framing Error
                            parity_err & ~rx_fifo_empty, // Parity Error
                            overrun_error, // Overrun Error
                            ~rx_fifo_empty};   // Data Ready
            end
            MSR0, MSR1: begin
              cts_change <= '0;
              reg_rdata <= {3'h0,        // Unused
                            uart_cts,    // current Clear to send
                            3'h0,
                            cts_change}; // Change in CTS detected
            end
            SCR0, SCR1: reg_rdata <= scratch_reg; // Readback scratch
            DLL: begin
              reg_rdata  <= baud_terminal_count[7:0];
              baud_reset <= '1;
            end
            DLM: begin
              reg_rdata  <= baud_terminal_count[15:8];
              baud_reset <= '1;
            end
            default: begin
              reg_rdata <= '0; // Not necessary
              reg_rresp <= AXI4_SLVERR; // Error
            end
          endcase // case (cpu_addr)
        end else begin // if (reg_arvalid)
          case ({reg_awvalid, reg_wvalid})
            2'b11: begin
              reg_addr    <= reg_awaddr;
              reg_we      <= '1;
              reg_din     <= reg_wdata;
              // Addr and data are available
              if (reg_bready) begin
                reg_awready <= '1;
                reg_wready  <= '1;
                reg_bvalid  <= '1;
              end else begin
                reg_awready <= '0;
                reg_wready  <= '0;
                reg_cs      <= REG_BRESP;
              end
            end
            2'b10: begin
              // Address only
              reg_awready <= '0;
              reg_addr    <= reg_awaddr;
              reg_cs      <= REG_W4DATA;
            end
            2'b01: begin
              reg_wready <= '0;
              reg_din    <= reg_wdata;
              reg_cs     <= REG_W4ADDR;
            end
          endcase // case ({reg_awvalid, reg_awvalid})
        end // else: !if(reg_arvalid)
      end // case: REG_IDLE
      REG_W4DATA: begin
        reg_we      <= '1;
        reg_din     <= reg_wdata;
        if (reg_bready) begin
          reg_awready <= '1;
          reg_wready  <= '1;
          reg_bvalid  <= '1;
          reg_cs      <= REG_IDLE;
        end else begin
          reg_awready <= '0;
          reg_wready  <= '0;
          reg_cs      <= REG_BRESP;
        end
      end
      REG_W4ADDR: begin
        reg_addr    <= reg_awaddr;
        reg_we      <= '1;
        if (reg_bready) begin
          reg_awready <= '1;
          reg_wready  <= '1;
          reg_bvalid  <= '1;
          reg_cs      <= REG_IDLE;
        end else begin
          reg_awready <= '0;
          reg_wready  <= '0;
          reg_cs      <= REG_BRESP;
        end
      end
      REG_BRESP: begin
        if (reg_bready) begin
          reg_awready <= '1;
          reg_wready  <= '1;
          reg_bvalid  <= '1;
          reg_cs      <= REG_IDLE;
        end else begin
          reg_awready <= '0;
          reg_wready  <= '0;
          reg_cs      <= REG_BRESP;
        end
      end
      REG_W4RDREADY: begin
        if (reg_rready) begin
          reg_arready <= '1;
          reg_cs      <= REG_IDLE;
        end
      end
    endcase // case (reg_cs)

    // Reset clause
    if (~sys_rstn) begin
      rx_fifo_pop         <= '0;
    end
  end // always @ (posedge reg_clk)

  always @(posedge sys_clk) begin

    tx_fifo_push  <= '0;
    reset_rx_fifo <= '0;
    reset_tx_fifo <= '0;
    reg_bresp     <= AXI4_OKAY; // Okay


    // Detect overrun
    if (rx_fifo_push & ~rx_fifo_pop & rx_fifo_full) overrun_error <= 1'b1;
    else if (~rx_fifo_full) overrun_error <= 1'b0;

    // set int_status and cpu_int
    if (en_rx_status_change && (overrun_error ||
                                parity_err & ~rx_fifo_empty ||
                                break_det & ~rx_fifo_empty ||
                                frame_err & ~rx_fifo_empty))
      {int_status, cpu_int} <= 4'b0110;
    else if (en_rx_data_avail && rx_data_avail)
      // This might be a cheat, but I didn't see the purpose of setting
      // a threshold and going off even if 1 piece of data was in the FIFO
      // I might have read the spec wrong. This is better anyways.
      {int_status, cpu_int} <= 4'b0100;
    else if (char_timeout)
      // fixme!!!!
      {int_status, cpu_int} <= 4'b1100;
    else if (en_tx_fifo_empty && thr_empty)
      // fixme, set a flag when go empty and clear when
      // reading this
      {int_status, cpu_int} <= 4'b0010;
    else if (en_msr_change && cts_change)
      {int_status, cpu_int} <= 4'b0000;
    else
      cpu_int <= 1'b1;

    // detect shift register going empty and set thr_empty
    tx_shift_empty_d <= tx_shift_empty;
    if (tx_shift_empty & ~tx_shift_empty_d && tx_fifo_empty) thr_empty <= 1'b1;

    if (reg_we) begin
      case ({dlab, reg_addr})
        RBR_THR: begin
          thr_empty <= 1'b0;
          // RX Buffer Register, TX Holding Register
          tx_fifo_push      <= '1;
          tx_fifo_din[7:0]  <= reg_din;
        end
        IER_IER: begin
          {en_rx_data_avail,
           en_tx_fifo_empty,
           en_rx_status_change,
           en_msr_change} <= reg_din[3:0];
        end
        IIR_FCR0, IIR_FCR1: begin
          // FIFO control register
          fifo_enable   <= reg_din[0];
          if (reg_din[1]) begin
            reset_rx_fifo <= '1;
          end
          if (reg_din[2]) begin
            reset_tx_fifo <= '1;
          end
          // reg_din[3] DMA mode, not supported currently
          // reg_din[4] Reserved
          // reg_din[5] Reserved
          // Threshold set for RX. 1/2 the 16 FIFO of 16550
          case (reg_din[7:6])
            2'h0: rx_thresh <= 4'h1;
            2'h1: rx_thresh <= 4'h2;
            2'h2: rx_thresh <= 4'h4;
            2'h3: rx_thresh <= 4'h7;
          endcase // case (reg_din[7:6])
        end // case: IIR_FCR0,...
        LCR0, LCR1: begin
          dlab     <= reg_din[7]; // 1 = select config registers
          break_en <= reg_din[6]; // (not currently used)
          parity   <= reg_din[5:3];   /* Parity setting
                                       * [5:3]    Setting
                                       *  xx0     No Parity
                                       *  001     Odd Parity
                                       *  010     Even Parity
                                       *  101     High Parity (stick)
                                       *  111     Low Parity (stick)
                                       */
        end // case: LCR0, LCR1
        MCR0, MCR1: begin
          autoflow  <= reg_din[5]; // Generate RTS automatically
          loopback  <= reg_din[4]; // Loopback mode
          force_rts <= reg_din[1]; // RTS
        end
        SCR0, SCR1: scratch_reg <= reg_din; // scratch register
        DLL:        baud_terminal_count[7:0]  <= reg_din;
        DLM:        baud_terminal_count[15:8] <= reg_din;
        default:    reg_bresp  <= AXI4_SLVERR; // Bad address

      endcase // case (reg_addr)
    end // if (reg_we)

    // Reset clause
    if (~sys_rstn) begin
      thr_empty           <= 1'b0;
      dlab                <= 1'b0;
      break_en            <= 1'b0;
      parity              <= 3'h0;
      autoflow            <= 1'b0;
      loopback            <= 1'b0;
      force_rts           <= 1'b0;
      fifo_enable         <= 1'b1;
      reset_rx_fifo       <= 1'b0;
      reset_tx_fifo       <= 1'b0;
      rx_thresh           <= '0; //2'h1; // Default to depth of 1 to signal data ready
      en_rx_data_avail    <= 1'b0;
      en_tx_fifo_empty    <= 1'b0;
      en_rx_status_change <= 1'b0;
      en_msr_change       <= 1'b0;
      tx_fifo_push        <= 1'b0;
      overrun_error       <= 1'b0;
      baud_terminal_count <= 16'd247; // 57600
    end // if (~sys_rstn)

  end // always @ (posedge sys_clk)

  // FIFO blocks
  // These are synchronous due to the nature of the clocks. The presentation
  // will go over asynchronous FIFOs
  // Need to store:
  // framing error
  // parity error
  logic [4:0] wr_data_count;
  assign data_avail = wr_data_count > rx_thresh;
  xpm_fifo_sync
    #
    (
     // Common module parameters
     .FIFO_WRITE_DEPTH (16),
     .WRITE_DATA_WIDTH (11),
     .READ_MODE        ("fwft")
     )
  u_rx
    (
     // Common module ports
     .sleep            ('0),
     .rst              (reset_rx_fifo),

     // Write Domain ports
     .wr_clk           (sys_clk),
     .wr_en            (rx_fifo_push),
     .din              ({rx_break_det,
                         rx_parity_err,
                         rx_frame_err,
                         rx_fifo_din}),
     .full             (rx_fifo_full),
     .wr_data_count    (wr_data_count),

     // Read Domain ports
     .rd_en            (rx_fifo_pop),
     .dout             ({break_det,
                         parity_err,
                         frame_err,
                         rx_fifo_out}),
     .empty            (rx_fifo_empty)
     );

  assign rx_fifo_error = break_det | parity_err | frame_err;

  xpm_fifo_sync
    #
    (
     // Common module parameters
     .FIFO_WRITE_DEPTH (16),
     .WRITE_DATA_WIDTH (11),
     .READ_MODE        ("fwft")
     )
  u_tx
    (
     // Common module ports
     .sleep            ('0),
     .rst              (reset_tx_fifo),

     // Write Domain ports
     .wr_clk           (sys_clk),
     .wr_en            (tx_fifo_push),
     .din              (tx_fifo_din),
     .full             (tx_fifo_full),

     // Read Domain ports
     .rd_en            (tx_fifo_pop),
     .dout             (tx_fifo_dout),
     .empty            (tx_fifo_empty)
     );

  assign tx_data_avail = ~tx_fifo_empty;

endmodule // uart

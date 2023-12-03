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
`define NEW_RTS 1
module tb_uart;

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
    // Baud    7x speed  Period      BAUDCNT_HI BAUDCNT_LO
    // 300     2100      476190.476  8'hBA      8'h03
    // 1200    8400      119047.619  8'h2E      8'h81
    // 2400    16800      59523.810  8'h17      8'h40
    // 4800    33600      29761.905  8'h0B      8'hA0
    // 9600    67200      14880.952  8'h05      8'hD0
    // 14400   100800      9920.635  8'h03      8'hE0
    // 19200   134400      7440.476  8'h02      8'hE8
    // 28800   201600      4960.317  8'h01      8'hF0
    // 38400   268800      3720.238  8'h01      8'h74
    // 57600   403200      2480.159  8'h00      8'hF8
    IIR_FCR1   = 4'hA, // interrupt ID register, FIFO control register
    LCR1       = 4'hB, // Line Control Register
    MCR1       = 4'hC, // Modem Control Register
    LSR1       = 4'hD, // Line Status Register
    MSR1       = 4'hE, // Modem Status Register
    SCR1       = 4'hF; // Scratch register

  // Which UART are we using (UART1 only used in non loopback testing
  localparam
    UART0 = 1'b0,
    UART1 = 1'b1;

  // Utility signals
  reg          sys_clk; // 100 Mhz for this example
  reg          sys_rstn; // Active low reset

  // CPU interface
  wire [1:0]   cpu_int; // interrupt

  logic [1:0]  reg_awvalid;
  logic [1:0]  reg_awready;
  logic [2:0]  reg_awaddr[2];

  logic [1:0]  reg_wvalid;
  logic [1:0]  reg_wready;
  logic [7:0]  reg_wdata[2];

  logic [1:0]  reg_bready;
  logic [1:0]  reg_bvalid;
  logic [1:0]  reg_bresp[2];

  logic [1:0]  reg_arvalid;
  logic [1:0]  reg_arready;
  logic [2:0]  reg_araddr[2];

  logic [1:0]  reg_rready;
  logic [1:0]  reg_rvalid;
  logic [7:0]  reg_rdata[2];
  logic [1:0]  reg_rresp[2];

  // External pins
  logic        uart_ctsn; // Clear to send
  wire         uart_rx; // RX pin
  logic        uart_rtsn; // Request to send
  wire         uart_tx;   // TX pin
  wire         uart_rx_1, uart_tx_1;
  logic        uart_ctsn_1, uart_rtsn_1;

  // Testbench stuff
  reg [7:0]    test_reg[1:0]; // Holding value for reading.
  reg [7:0]    data_reg[1:0]; // Holding value for reading.
  reg          test_failed; // set if test failed
  reg          stop_on_fail; // if set, stop on failure
  reg [7:0]    send_data[1:0]; // Single value for testing
  reg [7:0]    exp_data[$]; // Queue to store expected data
  reg          ext_loopback; // Set for external loopback
  // For sending between two UARTs create a small data shift register
  reg [7:0]    data_shift[15:0];
  reg [15:0]   par_shift; // Shift in parity for verification
  reg [15:0]   frame_shift; // Shift in parity for verification
  reg [3:0]    addr_in, addr_out;
  reg [15:0]   clk_set; // set the clock values
  reg          enable_uart1_rx; // Enable RX on UART1
  integer      i, j, k; // loop variables
  integer      parity_count, break_count, frame_count;
  reg          inj_par_err; // set if we are injecting parity error
  reg          par_error_test; // Set if we are checking parity error stats
  reg          frame_error_test; // Test framing error
  reg          disable_rx; // For overrun, disable RX

  // Measure the baudrate
  reg          baud_measure; // Measure the baud rate
  time         rtsn[2]; // Start and stop
  real         time_diff, baud_clock;
  integer      baud_loop; // Make it easy on the baud rate test
  real         baud_diff, baud_percent;
  real         exp_baud; // Expected Baud Rate

  // UART 0 will be the TX UART
  uart u_uart1
    (
     // Utility signals
     .sys_clk     (sys_clk),
     .sys_rstn    (sys_rstn),

     // CPU interface
     .cpu_int             (cpu_int[0]),
     .reg_awvalid         (reg_awvalid[0]),
     .reg_awready         (reg_awready[0]),
     .reg_awaddr          (reg_awaddr[0]),

     .reg_wvalid          (reg_wvalid[0]),
     .reg_wready          (reg_wready[0]),
     .reg_wdata           (reg_wdata[0]),

     .reg_bready          (reg_bready[0]),
     .reg_bvalid          (reg_bvalid[0]),
     .reg_bresp           (reg_bresp[0]),

     .reg_arvalid         (reg_arvalid[0]),
     .reg_arready         (reg_arready[0]),
     .reg_araddr          (reg_araddr[0]),

     .reg_rready          (reg_rready[0]),
     .reg_rvalid          (reg_rvalid[0]),
     .reg_rdata           (reg_rdata[0]),
     .reg_rresp           (reg_rresp[0]),

     // External pins
     .uart_ctsn   (uart_ctsn),
     .uart_rx     (uart_rx),
     .uart_rtsn   (uart_rtsn),
     .uart_tx     (uart_tx)
     );

  // UART 0 will be the TX UART
  uart u_uart2
    (
     // Utility signals
     .sys_clk     (sys_clk),
     .sys_rstn    (sys_rstn),

     // CPU interface
     .cpu_int             (cpu_int[1]),
     .reg_awvalid         (reg_awvalid[1]),
     .reg_awready         (reg_awready[1]),
     .reg_awaddr          (reg_awaddr[1]),

     .reg_wvalid          (reg_wvalid[1]),
     .reg_wready          (reg_wready[1]),
     .reg_wdata           (reg_wdata[1]),

     .reg_bready          (reg_bready[1]),
     .reg_bvalid          (reg_bvalid[1]),
     .reg_bresp           (reg_bresp[1]),

     .reg_arvalid         (reg_arvalid[1]),
     .reg_arready         (reg_arready[1]),
     .reg_araddr          (reg_araddr[1]),

     .reg_rready          (reg_rready[1]),
     .reg_rvalid          (reg_rvalid[1]),
     .reg_rdata           (reg_rdata[1]),
     .reg_rresp           (reg_rresp[1]),

     // External pins
     .uart_ctsn   (uart_ctsn_1),
     .uart_rx     (uart_rx_1),
     .uart_rtsn   (uart_rtsn_1),
     .uart_tx     (uart_tx_1)
     );

  assign reg_bready = '1;
  assign reg_rready = '1;

  // Loopback or second UART
  assign uart_ctsn   = (ext_loopback) ? uart_rtsn   : uart_rtsn_1;
  assign uart_rx     = (ext_loopback) ? uart_tx     : uart_tx_1;
  assign uart_ctsn_1 = (ext_loopback) ? uart_rtsn_1 : uart_rtsn;
  assign uart_rx_1   = (ext_loopback) ? uart_tx_1   : uart_tx;

  // Generate a 100Mhz system clock
  always begin
    #10 sys_clk = 0;
    #10 sys_clk = 1;
  end

  // Default the rstn and csn (the only signal affecting the core)
  initial begin
    inj_par_err      = '0;
    par_shift        = '0;
    frame_shift      = '0;
    parity_count     = '0;
    break_count      = '0;
    frame_count      = '0;
    addr_in          = '0;
    addr_out         = '0;
    ext_loopback     = '0;
    baud_measure     = '0;
    stop_on_fail     = '0;
    par_error_test   = '0;
    frame_error_test = '0;
    disable_rx = '0;
    test_failed  = '0;  // test passed unless otherwise set
    sys_rstn = '1;
    reg_awvalid = '0;
    reg_wvalid = '0;
    reg_arvalid = '0;
    repeat (10) @(posedge sys_clk);
    // Generate a reset
    sys_rstn <= 1'b0;
    repeat (10) @(posedge sys_clk);
    sys_rstn <= 1'b1;
    repeat (10) @(posedge sys_clk);
`include "the_test.h"
    $display(" %d Parity errors detected", parity_count);
    $display(" %d Frame errors detected", frame_count);
    $display(" %d Breaks detected", break_count);
    if (test_failed) begin
      $display("Test FAILED!!!!");
    end else begin
      $display("Test PASSED!!!!");
    end
    $stop;
    //$finish;
  end

  // Write a register in the design
  task automatic cpu_wr_reg;
    input       uart_sel;
    input [2:0] addr;
    input [7:0] din;

    begin
      reg_awvalid[uart_sel]  <= '1;
      reg_awaddr[uart_sel]   <= addr;
      reg_wvalid[uart_sel]   <= '1;
      reg_wdata[uart_sel]    <= din;
      @(posedge sys_clk);
      // Cheating here because we know the device is always ready
      reg_awvalid[uart_sel]  <= '0;
      reg_wvalid[uart_sel]   <= '0;
      @(posedge sys_clk);
      // Wait a clock cycle for the bresp
    end
  endtask // cpu_wr

  // This task will do a read modify write of the LCR register to set the
  // DLAB bit to the desired value
  task automatic set_dlab;
    input uart_sel;
    input value;

    begin
      cpu_rd_reg(uart_sel, LCR0);
      cpu_wr_reg(uart_sel, LCR0, {value, test_reg[uart_sel][6:0]});
    end
  endtask // cpu_wr

  // Simple task to write data to the UART (calls cpu_wr_reg 2x)
  task automatic cpu_wr_data;
    input        uart_sel;
    input [7:0]  din;

    begin
      cpu_wr_reg(uart_sel, RBR_THR, din[7:0]);
    end
  endtask // cpu_wr

  // Simple task to read a register. Data is stored in test_reg
  task automatic cpu_rd_reg;
    input       uart_sel;
    input [2:0] addr;

    begin
      reg_arvalid[uart_sel]  <= '1;
      reg_araddr[uart_sel]   <= addr;
      @(posedge sys_clk);
      reg_arvalid[uart_sel]  <= '0;
      while (!reg_rvalid[uart_sel]) @(posedge sys_clk);
      //@(posedge sys_clk);
      test_reg[uart_sel]  = reg_rdata[uart_sel];
    end
  endtask // cpu_rd_reg

  // Verify against expected value.
  // A mask is provided for ignoring bits you may not care about, i.e.
  // interrupts. Ex:
  // cpu_rd_reg_verify(IIR_FCR0, 8'h00, 8'h01) will check bit 0 for interrupt
  // bit is '0'
  task automatic cpu_rd_reg_verify;
    input       uart_sel;
    input [2:0] addr;
    input [7:0] exp_data;
    input [7:0] data_mask; // 1 if we are checking this bit

    begin
      cpu_rd_reg(uart_sel, addr);
      if ((test_reg[uart_sel] & data_mask) == (exp_data & data_mask)) begin
        $display($stime, " PASS: Expected data: %h, Mask: %h, Actual Data: %h",
                 exp_data, data_mask, test_reg[uart_sel]);
      end else begin
        $display($stime, " FAIL: Expected data: %h, Mask: %h, Actual Data: %h",
                 exp_data, data_mask, test_reg[uart_sel]);
        test_failed = 1'b1;
        if (stop_on_fail) $stop;
      end
    end
  endtask // cpu_rd_reg

  // Siple task to read data (2x call to above task)
  task automatic cpu_rd_data;
    input uart_sel;
    begin
      // fixme: need to read stats
      cpu_rd_reg(uart_sel, RBR_THR);
      data_reg[uart_sel][7:0] = test_reg[uart_sel];
    end
  endtask // cpu_rd_dat

  // Verify against expected data value
  task automatic cpu_rd_dat_verify;
    input        uart_sel;
    input [7:0]  exp_data;
    // add expected stats

    begin
      cpu_rd_reg(uart_sel, LSR0);
      parity_count <= parity_count + test_reg[uart_sel][2];
      frame_count  <= frame_count  + test_reg[uart_sel][3];
      break_count  <= break_count  + test_reg[uart_sel][4];

      cpu_rd_data(uart_sel);
      if (data_reg[uart_sel] == exp_data) begin
        $display($stime, " PASS: Data Comparison %h == %h",
                 data_reg[uart_sel], exp_data);
      end else begin
        $display($stime, " FAIL: Data Comparison %h != %h",
                 data_reg[uart_sel], exp_data);
        test_failed = 1'b1;
        if (stop_on_fail) $stop;
      end
    end
  endtask // cpu_rd_dat

  // Verify against expected data value
  task automatic cpu_rd_all_verify;
    input        uart_sel;
    input [7:0]  exp_data;
    input        parity_error;
    input        break_error;
    input        frame_error;
    // add expected stats

    begin
      cpu_rd_reg(uart_sel, LSR0);
      parity_count <= parity_count + test_reg[uart_sel][2];
      frame_count  <= frame_count  + test_reg[uart_sel][3];
      break_count  <= break_count  + test_reg[uart_sel][4];

      if (test_reg[uart_sel][2] == parity_error) begin
        if (test_reg[uart_sel][2])
          $display("PASS: Parity Error Detected and Expected");
      end else begin
        $display("FAIL: Parity Error Detected and NOT Expected");
        test_failed = 1'b1;
        if (stop_on_fail) $stop;
      end
      if (test_reg[uart_sel][3] == frame_error) begin
        if (test_reg[uart_sel][3])
          $display("PASS: Frame Error Detected and Expected");
      end else begin
        $display("FAIL: Frame Error Detected and NOT Expected");
        test_failed = 1'b1;
        if (stop_on_fail) $stop;
      end

      if (test_reg[uart_sel][4] == break_error) begin
        if (test_reg[uart_sel][4])
          $display("PASS: Break Detected and Expected");
      end else begin
        $display("FAIL: Break Detected and NOT Expected");
        test_failed = 1'b1;
        if (stop_on_fail) $stop;
      end

      cpu_rd_data(uart_sel);
      if (data_reg[uart_sel] == exp_data) begin
        $display($stime, " PASS: Data Comparison %h == %h",
                 data_reg[uart_sel], exp_data);
      end else begin
        $display($stime, " FAIL: Data Comparison %h != %h",
                 data_reg[uart_sel], exp_data);
        test_failed = 1'b1;
        if (stop_on_fail) $stop;
      end
    end
  endtask // cpu_rd_dat

  // monitor the RTS/ CTS for speed measurement
  // To use this, send in one word to TX.
  // A cheat snooping on an internal signal. An option would be to bring
  // out a different form of rtsn for this
  logic enable_tx_pos, enable_tx_neg;
  always @(posedge sys_clk) enable_tx_pos <= u_uart1.enable_tx;
  always @(negedge sys_clk) enable_tx_neg <= u_uart1.enable_tx;
  always @(posedge sys_clk) begin
    //if (~enable_tx_pos && u_uart1.enable_tx) rtsn_start = $time;
    if (u_uart1.tx_baudclk_en) begin
      rtsn[0] <= $time;
      rtsn[1] <= rtsn[0];
    end
  end
  always @(negedge sys_clk) begin
    if (enable_tx_neg && ~u_uart1.enable_tx) begin
      //rtsn_stop = $time;
      time_diff = (rtsn[0] *1e-9) - (rtsn[1] * 1e-9);
      baud_clock = 1/(time_diff * 7);
      if (baud_measure) begin
        $display("%t Baud Rate: %f", $stime, baud_clock);
        baud_diff = exp_baud - baud_clock;
        baud_percent = (baud_diff/exp_baud) * 100;
        $display("%t Percent Error %f", $stime, baud_percent);
      end
    end // always @ (posedge uart_rtsn)
  end // always @ (negedge sys_clk)

  // poll for RX side
  always @(posedge sys_clk) begin
    // This is for the polling test. Below is for the interrupt test
    while (enable_uart1_rx) begin

      $display("Poll for RX data Available.");
      cpu_rd_reg(UART1, LSR0);
      while (~test_reg[UART1][0]) cpu_rd_reg(UART1, LSR0);

      $display("RX shows data available.");

      // Readback and check the data
      cpu_rd_dat_verify(UART1, data_shift[addr_out]);
      addr_out <= addr_out + 1'b1;
    end // while (enable_uart1_rx)

  end // always @ (posedge sys_clk)

  // Interrupt test RX logic
  always @(posedge sys_clk) begin
    if (!disable_rx && !cpu_int[1]) begin
      for (k = 0; k < 4; k = k + 1) begin
        //if (!par_error_test)
        //  cpu_rd_dat_verify(UART1, data_shift[addr_out]);
        //else
        cpu_rd_all_verify(UART1, data_shift[addr_out],
                          par_shift[addr_out], 1'b0,
                          frame_shift[addr_out]);
        addr_out <= addr_out + 1'b1;
      end
    end
  end

endmodule // tb_uart

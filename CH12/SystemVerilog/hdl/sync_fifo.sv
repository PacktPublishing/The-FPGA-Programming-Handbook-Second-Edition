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

module sync_fifo
  #
  (
   parameter DWIDTH = 13
   )
  (
   // Utility signals
   input 	     sys_clk, // 100 Mhz for this example
   input 	     sys_rstn, // Active low reset
   input 	     reset_fifo, // synchronous CPU controlled reset
   
   input 	     fifo_push, // Push into FIFO
   input 	     fifo_pop, // Pop from fifo
   input [DWIDTH-1:0]fifo_din, // Data in
   input [2:0] 	     data_thresh, // Data available threshold
   
   output reg [DWIDTH-1:0] fifo_out, // Data out
   output reg 	     data_avail, // Fifo has data available above threshold
   output 	     fifo_empty, // FIFO is empty
   output 	     fifo_full   // FIFO is Full
   );
   
   // FIFO blocks
   // These are synchronous due to the nature of the clocks. The presentation
   // will go over asynchronous FIFOs
   (* RAM_STYLE="DISTRIBUTED}" *) // For Xilinx and altera distributed
   reg [DWIDTH-1:0] 	     fifo_store[7:0]/* synthesis syn_ramstyle = "MLAB" */;
   reg [2:0] 	     addr_in, addr_out; // FIFO addressing
   reg 		     last_af;           // last almost full value
   wire 	     af;                // FIFO almost full
   reg [3:0] 	     fifo_count;        // Data in FIFO

   assign af = (fifo_count >= data_thresh);
   assign fifo_empty = ~|fifo_count;
   assign fifo_full  = fifo_count[3];
   
   always @ (posedge sys_clk) begin
      if (fifo_push) fifo_store[addr_in] <= fifo_din;
      fifo_out <= fifo_store[addr_out];
   end
   
   always @ (posedge sys_clk) begin
      last_af <= af;
      //data_avail <= ~last_af & rx_af; // Detect crossing threshold
      data_avail <= af; // set if above level
      
      case ({fifo_push, fifo_pop})
	// Don't increment if full
	2'b10: if(~fifo_count[3]) fifo_count <= fifo_count + 1'b1;
	// only decrement if we have data
	2'b01: fifo_count <= fifo_count - |fifo_count;
      endcase // case ({rx_fifo_push, rx_fifo_pop})

      if (fifo_push && ~fifo_count[3]) addr_in  <= addr_in  + 1;
      if (fifo_pop  && |fifo_count)    addr_out <= addr_out + 1;
	  
      if (~sys_rstn || reset_fifo) begin
	 addr_in    <= 3'b0;
	 addr_out   <= 3'b0;
	 fifo_count <= 4'b0;
	 //data_avail <= 1'b0; // Don't think we need to reset
      end
   end // always @ (posedge sys_clk)
   
endmodule // uart

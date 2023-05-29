// Simple loopback test
// Test the baud rates

baud_measure = 1'b1; // enable the display of the baud rate
for (baud_loop = 0; baud_loop < 10; baud_loop = baud_loop + 1) begin
   set_dlab(UART0, 1'b1);
   case (baud_loop)
     0: begin
	exp_baud = 57600;
	clk_set  = 16'h00F7;
	$display("Set Baud to 57600");
     end
     1: begin
	exp_baud = 38400;
	clk_set  = 16'h0173;
	$display("Set Baud to 38400");
     end
     2: begin
	exp_baud = 28800;
	clk_set  = 16'h01EF;
	$display("Set Baud to 28800");
     end
     3: begin
	exp_baud = 19200;
	clk_set  = 16'h02E7;
	$display("Set Baud to 19200");
     end
     4: begin
	exp_baud = 14400;
	clk_set  = 16'h03DF;
	$display("Set Baud to 14400");
     end
     5: begin
	exp_baud = 9600;
	clk_set  = 16'h05CF;
	$display("Set Baud to 9600");
     end
     6: begin
	exp_baud = 4800;
	clk_set  = 16'h0B9F;
	$display("Set Baud to 4800");
     end
     7: begin
	exp_baud = 2400;
	clk_set  = 16'h173F;
	$display("Set Baud to 2400");
     end
     8: begin
	exp_baud = 1200;
	clk_set  = 16'h2E7F;
	$display("Set Baud to 1200");
     end
     9: begin
	exp_baud = 300;
	clk_set  = 16'hB9FF;
	$display("Set Baud to 300");
     end
   endcase // case (baud_loop)
   cpu_wr_reg(UART0, DLL, clk_set[7:0]);
   cpu_wr_reg(UART0, DLM, clk_set[15:8]);
   
   //$display("Test No parity mode");
   //$display("Set Internal Loopback and Auto Flow control");
   cpu_wr_reg(UART0, LCR1, {2'b0, 3'b001, 3'b0});
   cpu_wr_reg(UART0, MCR1, 8'h30);
   
   //$display("Test LSR register");
   // we only care about bit 0, but bits 6&5 should be set as TX is idle
   //cpu_rd_reg_verify(LSR0, 8'h60, 8'hFF); // Check for exact match
   
   send_data[UART0] = $random;
   //$display("Write %h over the UART", send_data);
   set_dlab(UART0, 1'b0);
   cpu_wr_data(UART0, send_data[UART0]);
   
   // Wait for TX to no longer be idle
   cpu_rd_reg(UART0, LSR0);
   while (~test_reg[UART0][5]) cpu_rd_reg(UART0, LSR0);
   //$display("TX FIFO has data.");
   
   cpu_rd_reg(UART0, LSR0);
   while (~test_reg[UART0][6]) cpu_rd_reg(UART0, LSR0);
   //$display("TX Shifter has data.");
   
   // So now we poll on bit 0
   //$display("Poll for RX data Available.");
   cpu_rd_reg(UART0, LSR0);
   while (~test_reg[UART0][0]) cpu_rd_reg(UART0, LSR0);
   
   // Check the stats
   //cpu_rd_reg_verify(LSR0, 8'h61, 8'hFF); // Check for exact match

   /*
   $display("RX shows data available.");
   if (&test_reg[6:5]) begin
      $display("TX is now idle again");
   end else begin
      $display("TX is not idle again");
      test_failed = 1'b1;
      if (stop_on_fail) $stop;
   end
   */
   
   // Readback and check the data
   //cpu_rd_dat_verify(send_data);
   cpu_rd_data(UART0);
   
end // for (baud_loop = 0; baud_loop < 10; baud_loop = baud_loop + 1)






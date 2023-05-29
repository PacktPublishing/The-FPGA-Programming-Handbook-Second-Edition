// UART-UART test
// Send multiple packets using polling

$display("Set RX Baud to 57600 - 2/7");
set_dlab(UART1, 1'b1);
cpu_wr_reg(UART1, DLL, 8'hF6);
cpu_wr_reg(UART1, DLM, 8'h00);

$display("Set Auto Flow control");
cpu_wr_reg(UART1, MCR1, 8'h20);

$display("Set FIFO control for a threshold of 4");
cpu_wr_reg(UART1, IIR_FCR1, 8'h81);

$display("Set RX interrupt enable on fifo threshold");
cpu_wr_reg(UART1, IIR_FCR1, 8'h81);

// parity == 001
$display("Test Odd parity mode");
cpu_wr_reg(UART1, LCR0, {2'b0, 3'b001, 3'b0});

// Set interrupt on data available
cpu_wr_reg(UART1, IER_IER, 8'h08);
set_dlab(UART1, 1'b0);

// For polling
//$display("Enabling RX UART");
//enable_uart1_rx = 1'b1;

$display("Set TX Baud to 57600");
set_dlab(UART0, 1'b1);
//cpu_wr_reg(DLL, 8'hF7);
cpu_wr_reg(UART0, DLL, 8'hF7);
cpu_wr_reg(UART0, DLM, 8'h00);

$display("Set Auto Flow control");
cpu_wr_reg(UART0, MCR1, 8'h20);

set_dlab(UART0, 1'b0);
// Set interrupt on tx_fifo_empty
cpu_wr_reg(UART0, IER_IER, 8'h04);

// parity == 001
$display("Test Odd parity mode");
cpu_wr_reg(UART0, LCR0, {2'b0, 3'b001, 3'b0});

send_data[UART0] = $random;
exp_data.push_front(send_data[UART0]);
data_shift[addr_in] = send_data[UART0];
addr_in = addr_in + 1;
$display("Write %h over the UART", send_data[UART0]);
set_dlab(UART0, 1'b0);
cpu_wr_data(UART0, send_data[UART0]);

// Wait for TX to no longer be idle
cpu_rd_reg(UART0, LSR0);
while (~test_reg[UART0][5]) cpu_rd_reg(UART0, LSR0);
$display("TX FIFO has data.");

cpu_rd_reg(UART0, LSR0);
while (~test_reg[UART0][6]) cpu_rd_reg(UART0, LSR0);
$display("TX Shifter has data.");

$display("Test LSR register");
// we only care about bit 0, but bits 6&5 should be set as TX is idle
cpu_rd_reg_verify(UART0, LSR0, 8'h60, 8'h00); // Check for exact match

for (i = 0; i < 128; i = i + 8) begin
   $display("Poll on interrupt");
   while (cpu_int[0]) @(posedge sys_clk);
   $display("TX empty interrupt");

   // we only care about bit 0, but bits 6&5 should be set as TX is idle
   cpu_rd_reg_verify(UART0, LSR0, 8'h60, 8'hFF); // Check for exact match

   for (j = 0; j < 8; j = j + 1) begin
      // Excercise the FIFO, write in 4 words every time it's empty
      send_data[UART0] = $random;
      exp_data.push_front(send_data[UART0]);
      data_shift[addr_in] = send_data[UART0];
      addr_in = addr_in + 1;
      $display("Write %h over the UART", send_data[UART0]);
      set_dlab(UART0, 1'b0);
      cpu_wr_data(UART0, send_data[UART0]);
   end

   // Wait for TX to no longer be idle
   cpu_rd_reg(UART0, LSR0);
   while (~test_reg[UART0][5]) cpu_rd_reg(UART0, LSR0);
   $display("TX FIFO has data.");

   cpu_rd_reg(UART0, LSR0);
   while (~test_reg[UART0][6]) cpu_rd_reg(UART0, LSR0);
   $display("TX Shifter has data.");

   $display("Test LSR register");
   // we only care about bit 0, but bits 6&5 should be set as TX is idle
   cpu_rd_reg_verify(UART0, LSR0, 8'h60, 8'h00); // Check for exact match

   // So now we poll on bit 0
   $display("Poll for RX data Available.");
   cpu_rd_reg(UART1, LSR0);
   while (~test_reg[UART1][0]) cpu_rd_reg(UART1, LSR0);

   // Check the stats
   cpu_rd_reg(UART1, LSR0);
   while(test_reg[UART1][0]) begin
     $display("RX shows data available.");
     if (&test_reg[UART1][6:5]) begin
       $display("TX is now idle again");
     end else begin
       $display("TX is not idle again");
       test_failed = 1'b1;
       if (stop_on_fail) $stop;
     end

     // Readback and check the data
     cpu_rd_dat_verify(UART1, exp_data.pop_back());
     cpu_rd_reg(UART1, LSR0); // Check for exact match
   end // while (test_reg[UART1][0])

/*
   // So now we poll on bit 0
   $display("Poll for RX data Available.");
   cpu_rd_reg(UART0, LSR0);
   while (~test_reg[UART0][0]) cpu_rd_reg(UART0, LSR0);

   // Check the stats
   cpu_rd_reg_verify(UART0, LSR0, 8'h61, 8'hFF); // Check for exact match

   $display("RX shows data available.");
   if (&test_reg[UART0][6:5]) begin
      $display("TX is now idle again");
   end else begin
      $display("TX is not idle again");
      test_failed = 1'b1;
      if (stop_on_fail) $stop;
   end

   // Readback and check the data
   cpu_rd_dat_verify(UART0, send_data[UART0]);
  */

end // for (i = 0; i < 128; i = i + 1)

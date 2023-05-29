// Register test
// This test reads default values and test Write to and readback from registers
// that support this

// Scratch is easy since we can read and write it
$display("Testing Scratch Register");
set_dlab(UART0, 1'b0);
cpu_wr_reg(UART0, SCR0, 8'h55);
cpu_rd_reg_verify(UART0, SCR0, 8'h55, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, SCR1, 8'h55, 8'hFF); // Check for exact match @ alias local
cpu_wr_reg(UART0, SCR1, 8'hAA);
cpu_rd_reg_verify(UART0, SCR1, 8'hAA, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b0);
cpu_rd_reg_verify(UART0, SCR0, 8'hAA, 8'hFF); // Check for exact match @ alias local

// This only exists in DLAB 0
$display("Testing IER Register");
cpu_wr_reg(UART0, IER_IER, 8'h55);
cpu_rd_reg_verify(UART0, IER_IER, 8'h05, 8'hFF); // Check for exact match
cpu_wr_reg(UART0, IER_IER, 8'hAA);
cpu_rd_reg_verify(UART0, IER_IER, 8'h0A, 8'hFF); // Check for exact match

$display("Testing LCR Register");
cpu_wr_reg(UART0, LCR0, 8'h80);
cpu_rd_reg_verify(UART0, LCR0, 8'h80, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, LCR1, 8'h80, 8'hFF); // Check for exact match @ alias local
set_dlab(UART0, 1'b0);
cpu_wr_reg(UART0, LCR0, 8'h40);
cpu_rd_reg_verify(UART0, LCR0, 8'h40, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
// DLAB is set
cpu_rd_reg_verify(UART0, LCR1, 8'hC0, 8'hFF); // Check for exact match @ alias local
set_dlab(UART0, 1'b0);
cpu_wr_reg(UART0, LCR0, 8'h20);
cpu_rd_reg_verify(UART0, LCR0, 8'h20, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
// DLAB is set
cpu_rd_reg_verify(UART0, LCR1, 8'hA0, 8'hFF); // Check for exact match @ alias local
set_dlab(UART0, 1'b0);
cpu_wr_reg(UART0, LCR0, 8'h10);
cpu_rd_reg_verify(UART0, LCR0, 8'h10, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, LCR1, 8'h90, 8'hFF); // Check for exact match @ alias local
set_dlab(UART0, 1'b0);
cpu_wr_reg(UART0, LCR0, 8'h08);
cpu_rd_reg_verify(UART0, LCR0, 8'h08, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
// DLAB is set
cpu_rd_reg_verify(UART0, LCR1, 8'h88, 8'hFF); // Check for exact match @ alias local

cpu_wr_reg(UART0, LCR1, 8'h80);
set_dlab(UART0, 1'b0); // this actually clears the previous line
cpu_rd_reg_verify(UART0, LCR0, 8'h00, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, LCR1, 8'h80, 8'hFF); // Check for exact match @ alias local
cpu_wr_reg(UART0, LCR1, 8'h40);
set_dlab(UART0, 1'b0);
cpu_rd_reg_verify(UART0, LCR0, 8'h40, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, LCR1, 8'hC0, 8'hFF); // Check for exact match @ alias local
cpu_wr_reg(UART0, LCR1, 8'h20);
set_dlab(UART0, 1'b0);
cpu_rd_reg_verify(UART0, LCR0, 8'h20, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, LCR1, 8'hA0, 8'hFF); // Check for exact match @ alias local
cpu_wr_reg(UART0, LCR1, 8'h10);
set_dlab(UART0, 1'b0);
cpu_rd_reg_verify(UART0, LCR0, 8'h10, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, LCR1, 8'h90, 8'hFF); // Check for exact match @ alias local
cpu_wr_reg(UART0, LCR1, 8'h08);
set_dlab(UART0, 1'b0);
cpu_rd_reg_verify(UART0, LCR0, 8'h08, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, LCR1, 8'h88, 8'hFF); // Check for exact match @ alias local

set_dlab(UART0, 1'b0);
cpu_wr_reg(UART0, MCR0, 8'h02);
cpu_rd_reg_verify(UART0, MCR0, 8'h02, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, MCR1, 8'h02, 8'hFF); // Check for exact match @ alias local
cpu_wr_reg(UART0, MCR1, 8'h02);
cpu_rd_reg_verify(UART0, MCR1, 8'h02, 8'hFF); // Check for exact match @ alias local
set_dlab(UART0, 1'b0);
cpu_rd_reg_verify(UART0, MCR0, 8'h02, 8'hFF); // Check for exact match

cpu_wr_reg(UART0, MCR0, 8'h10);
cpu_rd_reg_verify(UART0, MCR0, 8'h10, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, MCR1, 8'h10, 8'hFF); // Check for exact match @ alias local
cpu_wr_reg(UART0, MCR1, 8'h10);
cpu_rd_reg_verify(UART0, MCR1, 8'h10, 8'hFF); // Check for exact match @ alias local
set_dlab(UART0, 1'b0);
cpu_rd_reg_verify(UART0, MCR0, 8'h10, 8'hFF); // Check for exact match

cpu_wr_reg(UART0, MCR0, 8'h20);
cpu_rd_reg_verify(UART0, MCR0, 8'h20, 8'hFF); // Check for exact match
set_dlab(UART0, 1'b1);
cpu_rd_reg_verify(UART0, MCR1, 8'h20, 8'hFF); // Check for exact match @ alias local
cpu_wr_reg(UART0, MCR1, 8'h20);
cpu_rd_reg_verify(UART0, MCR1, 8'h20, 8'hFF); // Check for exact match @ alias local
set_dlab(UART0, 1'b0);
cpu_rd_reg_verify(UART0, MCR0, 8'h20, 8'hFF); // Check for exact match

// These only exist in DLAB 1
$display("Testing DLL Register");
set_dlab(UART0, 1'b1);
cpu_wr_reg(UART0, DLL, 8'h55);
cpu_rd_reg_verify(UART0, DLL, 8'h55, 8'hFF); // Check for exact match
cpu_wr_reg(UART0, DLL, 8'hAA);
cpu_rd_reg_verify(UART0, DLL, 8'hAA, 8'hFF); // Check for exact match

$display("Testing DLM Register");
cpu_wr_reg(UART0, DLM, 8'h55);
cpu_rd_reg_verify(UART0, DLM, 8'h55, 8'hFF); // Check for exact match
cpu_wr_reg(UART0, DLM, 8'hAA);
cpu_rd_reg_verify(UART0, DLM, 8'hAA, 8'hFF); // Check for exact match

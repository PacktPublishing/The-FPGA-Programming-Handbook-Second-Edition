// streaming.sv
// ------------------------------------
// Demonstrate using the straming operators
// ------------------------------------
// Author : Frank Bruno
module streaming;

  logic [31:0]            packed_data_in;
  logic [3:0][7:0]        packed_array_in;
  logic [7:0]             unpacked_array_in[4];

  logic [3:0][7:0]        packed_array_out;
  logic [7:0]             unpacked_array_out[4];
  logic [31:0]            packed_data_out0;
  logic [31:0]            packed_data_out1;


  initial begin
    packed_data_in = 32'h76543210;

    $display("Packed data set to %h", packed_data_in);
    #10;
    // Unpack data into packed array
    packed_array_out   = {<<8{packed_data_in}};
    unpacked_array_out = {<<8{packed_data_in}};
    $display("Packing arrays into bytes");
    for (int i = 0; i < 4; i++) $display("  packed byte %d: %h", i, packed_array_out[i]);
    for (int i = 0; i < 4; i++) $display("unpacked byte %d: %h", i, unpacked_array_out[i]);
    #10;
    // Repack the data
    packed_data_out0   <= {<<8{packed_array_out}};
    packed_data_out1   <= {<<8{unpacked_array_out}};
    #10;
    $display("Packed data set to %h", packed_data_out0);
    $display("Packed data set to %h", packed_data_out1);

    // Reverse unpack data into packed array
    packed_array_out    = {>>8{packed_data_in}};
    unpacked_array_out  = {>>8{packed_data_in}};
    $display("Packing arrays into bytes");
    for (int i = 0; i < 4; i++) $display("  packed byte %d: %h", i, packed_array_out[i]);
    for (int i = 0; i < 4; i++) $display("unpacked byte %d: %h", i, unpacked_array_out[i]);
    #10;

    // Repack the data
    packed_data_out0   <= {>>8{packed_array_out}};
    packed_data_out1   <= {>>8{unpacked_array_out}};
    #10;
    $display("Packed data set to %h", packed_data_out0);
    $display("Packed data set to %h", packed_data_out1);

    // Pack
    #100;
    $finish;
  end
endmodule

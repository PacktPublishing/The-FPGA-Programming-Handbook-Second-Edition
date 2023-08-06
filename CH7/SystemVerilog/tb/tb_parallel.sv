`timescale 1ns/10ps
module tb_parallel;
  localparam CLK_PER    = 10;
  localparam ITERATIONS = 100;
  localparam MAX_DEALY = 3;

  logic               clk;
  logic [255:0][31:0] in_data;
  logic               in_valid;

  logic [39:0]        out_data;
  logic               out_valid;

  logic [39:0]        exp_data[$];
  logic [39:0]        sum, compare_data;
  int                 out_count;

  initial clk = '0;
  always begin
    clk = #(CLK_PER/2) ~clk;
  end

  initial begin
    out_count = 0;
    in_valid = '0;
    repeat (10) @(posedge clk);
    for (int i = 0; i < ITERATIONS; i++) begin
      in_valid = '1;
      sum = '0;
      for (int j = 0; j < 256; j++) begin
        in_data[j] = $random;
        sum        += in_data[j];
      end
      exp_data.push_front(sum);
      $display("Apply input vector %d", i);
      @(posedge clk);
      in_valid = '0;
      for (int k = 0; k < $urandom_range(0,3); k++) @(posedge clk);
    end // for (int i = 0; i < ITERATIONS; i++)
    repeat (100) @(posedge clk);
    $finish;
  end // initial begin

  always @(posedge clk) begin
    if (out_valid) begin
      compare_data = exp_data.pop_back();
      if (out_data != compare_data) begin
        $error("Data Mismatch on sample %d, %h != %h", out_count, out_data, compare_data);
      end
      out_count++;
    end
  end

  parallel u_parallel
    (
     .*
     );

endmodule

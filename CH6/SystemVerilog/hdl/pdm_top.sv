// pdm_top.sv
// ------------------------------------
// Top level of the PDM  module
// ------------------------------------
// Author : Frank Bruno, Guy Eschemann
// This file encompasses the PDM code for sampling the microphone input.
`timescale 1ns/10ps
module pdm_top
  #
  (
  parameter RAM_SIZE     = 16384,
  parameter CLK_FREQ     = 100,
  parameter SAMPLE_COUNT = 128
)
  (
  input wire          clk, // 100Mhz clock

  // Microphone interface
  output logic        m_clk,
  output logic        m_lr_sel,
  input wire          m_data,

  // Tricolor LED
  output logic        R,
  output logic        G,
  output logic        B,

  // Pushbutton interface
  input logic         BTNU,
  input logic         BTNC,

  // LED Array
  output logic [15:0] LED,

  // PDM output
  output wire         AUD_PWM,
  output wire         AUD_SD
);

  localparam SAMPLE_BITS = $clog2(SAMPLE_COUNT+1);
  assign AUD_SD = '1;

  (*mark_debug = "true" *)logic [SAMPLE_BITS-1:0] amplitude;
  (*mark_debug = "true" *)logic               amplitude_valid;

  (*async_reg = "true" *)logic [2:0]          button_csync = '0;
  logic                start_capture;
  logic                m_clk_en,              m_clk_en_del;

  assign m_lr_sel = '0;

  pdm_inputs u_pdm_inputs
  (
    .clk                 (clk), // 2.4Mhz

    // Microphone interface
    .m_clk               (m_clk),
    .m_clk_en            (m_clk_en),
    .m_data              (m_data),

    // Amplitude outputs
    .amplitude           (amplitude),
    .amplitude_valid     (amplitude_valid)
  );

  logic signed [SAMPLE_BITS:0] intensity;
  logic [SAMPLE_BITS-1:0]      light_count = 1;

  // Display capture amplitude using tricolor LED
  // We are looking for positive values, i.e. values > 64 and making the blue
  // intensity based on that.
  always @(posedge clk) begin
    // Generate 2.5Mhz/64 = 39.062kHz PWM counter
    if (m_clk_en) begin
      light_count <= light_count < SAMPLE_COUNT/2 ? light_count + 1'b1 : 1;
    end
    // Map amplitude from 0 - 128 to -64 - 4
    if (amplitude_valid) begin
      intensity <= signed'({1'b0, amplitude}) - SAMPLE_COUNT/2;
    end
    // Use absolute value of intensity to control the brightness of the blue LED
    // * |intensity| = 0  -> B is off for light count = 1..64 (0% duty cycle)
    // * |intensity| = 1  -> B is on  for light count = 1, off for light count = 2..64 (1.56% duty cycle)
    // ...
    // * |intensity| = 64 -> B is on  for light count = 1..64 (100% duty cycle)
    if (intensity < 0) B <= light_count <= -intensity;
    else               B <= light_count <=  intensity;
    R <= '0;
    G <= '0;
  end

  // Capture RAM
  logic [SAMPLE_COUNT-1:0] amplitude_store[RAM_SIZE];
  logic                    start_playback;        // Note that we test the end of the memory defined in the event it is
  // not a power of two. If the ram were a power of two we could

  logic [$clog2(RAM_SIZE)-1:0] ram_wraddr;
  logic [$clog2(RAM_SIZE)-1:0] ram_rdaddr;
  logic                        ram_we;
  logic [SAMPLE_COUNT-1:0]     ram_dout;
  logic [15:0]                 clr_led;

  initial begin
    ram_wraddr     = '0;
    ram_we         = '0;
    start_capture  = '0;
    start_playback = '0;
    LED            = '0;
  end

  // Capture the Audio data
  always @(posedge clk) begin
    button_csync <= button_csync << 1 | BTNC;
    ram_we       <= '0;
    for (int i = 0; i < 16; i++)
      if (clr_led[i]) LED[i] <= '0;

    if (ram_we) ram_wraddr <= ram_wraddr + 1'b1;
    if (button_csync[2:1] == 2'b01) begin
      ram_wraddr    <= '0;
      start_capture <= '1;
      LED           <= '0;
    end else if (start_capture && amplitude_valid) begin
      LED[ram_wraddr[$clog2(RAM_SIZE)-1:$clog2(RAM_SIZE)-4]] <= '1;
      ram_we                      <= '1;
      if (ram_wraddr == RAM_SIZE - 1) begin
         start_capture <= '0;
      end
    end
  end // always @ (posedge clk)

  always @(posedge clk) begin
    if (ram_we) amplitude_store[ram_wraddr] <= amplitude;
    ram_dout <= amplitude_store[ram_rdaddr];
  end

  logic       AUD_PWM_en;
        // Note that we test the end of the memory defined in the event it is
  // not a power of two. If the ram were a power of two we could

  // Playback the audio
  pwm_outputs
  #
  (
  .CLK_FREQ         (CLK_FREQ), // Mhz
  .RAM_SIZE         (RAM_SIZE) // Depth of sample storage
  )
  u_pwm_outputs
  (
    .clk              (clk),

    .start_playback   (BTNU),
    .ram_rdaddr       (ram_rdaddr),
    .ram_sample       (ram_dout),

    .AUD_PWM_en       (AUD_PWM_en),

    .clr_led          (clr_led)
  );

  assign AUD_PWM = ~AUD_PWM_en ? '0 : 'z;

endmodule // pdm_top

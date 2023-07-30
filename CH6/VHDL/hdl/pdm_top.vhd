-- pdm_top.vhd
-- ------------------------------------
-- Top level of the PDM  module
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- This file encompasses the PDM code for sampling the microphone input.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

use work.util_pkg.all;

entity pdm_top is
  generic(
    RAM_SIZE     : natural := 16384;    -- bytes
    CLK_FREQ     : natural := 100;      -- MHz
    SAMPLE_COUNT : natural := 128
  );
  port(
    clk      : in  std_logic;
    -- Microphone interface
    m_clk    : out std_logic;
    m_lr_sel : out std_logic;
    m_data   : in  std_logic;
    -- Tricolor LED
    R, G, B  : out std_logic;
    -- Pushbutton interface
    BTNU     : in  std_logic;
    BTNC     : in  std_logic;
    -- LED Array
    LED      : out std_logic_vector(15 downto 0) := (others => '0');
    -- PDM output
    AUD_PWM  : out std_logic;
    AUD_SD   : out std_logic
  );
end entity pdm_top;

architecture rtl of pdm_top is

  constant RAM_ADDR_BITS : natural := clog2(RAM_SIZE);
  constant SAMPLE_BITS   : natural := clog2(SAMPLE_COUNT + 1);
  constant MCLK_FREQ     : natural := 2500000;
  constant INPUT_FREQ    : natural := 25000;

  type array_2d is array (natural range <>) of std_logic_vector(SAMPLE_BITS - 1 downto 0);

  signal amplitude_store : array_2d(0 to RAM_SIZE - 1); -- capture RAM
  signal ram_wraddr      : unsigned(RAM_ADDR_BITS - 1 downto 0) := (others => '0');
  signal ram_rdaddr      : unsigned(RAM_ADDR_BITS - 1 downto 0) := (others => '0');
  signal ram_we          : std_logic                            := '0';
  signal ram_dout        : std_logic_vector(SAMPLE_BITS - 1 downto 0);
  signal amplitude       : std_logic_vector(SAMPLE_BITS - 1 downto 0);
  signal amplitude_valid : std_logic;
  signal button_csync    : std_logic_vector(2 downto 0);
  signal start_capture   : std_logic                            := '0';
  signal m_clk_en        : std_logic;
  signal clr_led         : std_logic_vector(15 downto 0)        := (others => '0');
  signal AUD_PWM_en      : std_logic;

  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of amplitude, amplitude_valid : signal is "TRUE";
  attribute ASYNC_REG  : string;
  attribute ASYNC_REG of button_csync : signal is "TRUE";

begin
  AUD_SD   <= '1';
  m_lr_sel <= '0';

  u_pdm_inputs : entity work.pdm_inputs
    generic map(
      CLK_FREQ     => CLK_FREQ,
      MCLK_FREQ    => MCLK_FREQ,
      SAMPLE_COUNT => SAMPLE_COUNT
    )
    port map(
      clk             => clk,
      m_clk           => m_clk,
      m_clk_en        => m_clk_en,
      m_data          => m_data,
      amplitude       => amplitude,
      amplitude_valid => amplitude_valid);

  -- Display capture amplitude using tricolor LED
  -- We are looking for positive values, i.e. values > 64 and making the blue
  -- intensity based on that.
  process(clk)
    variable intensity   : signed(SAMPLE_BITS downto 0)          := (others => '0');
    variable light_count : natural range 1 to (SAMPLE_COUNT / 2) := 1; -- range [1, 64]
  begin
    if rising_edge(clk) then
      -- Generate 2.5 MHz / 64 = 39.062 kHz PWM counter
      if m_clk_en then
        light_count := light_count + 1 when light_count < (SAMPLE_COUNT / 2) else 1;
      end if;
      -- Capture amplitude sample and map it from range [0, 128] to [-64, 64]
      if amplitude_valid then
        intensity := signed('0' & amplitude) - SAMPLE_COUNT / 2;
      end if;
      -- Use absolute value of intensity to control the brightness of the blue LED
      --  * |intensity| = 0  -> B is OFF for light_count = 1..64 (0% duty cycle)
      --  * |intensity| = 1  -> B is ON for light_count = 1, OFF for light_count = 2..64 (1.56% duty cycle)
      --  * |intensity| = 64 -> B is ON for light_count = 1..64 (100% duty cycle)
      B <= '1' when light_count <= abs (intensity) else '0';
      --
      R <= '0';
      G <= '0';
    end if;
  end process;

  -- Capture the Audio data
  capture : process(clk)
    variable led_index : integer range 0 to LED'high;
  begin
    if rising_edge(clk) then
      button_csync <= button_csync(1 downto 0) & BTNC;
      ram_we       <= '0';

      -- Clear LEDs (during playback)
      for i in LED'range loop
        if clr_led(i) then
          LED(i) <= '0';
        end if;
      end loop;

      -- Generate RAM write address
      if ram_we then
        if ram_wraddr = RAM_SIZE - 1 then
          ram_wraddr <= (others => '0');
        else
          ram_wraddr <= ram_wraddr + 1;
        end if;
      end if;

      if button_csync(2 downto 1) = "01" then
        start_capture <= '1';
        LED           <= (others => '0');
      elsif start_capture and amplitude_valid then
        -- Turn ON the LED corresponding to the current write address region:
        -- 0x0000 - 0x03FF -> LED 0
        -- 0x0400 - 0x07FF -> LED 1
        -- ...
        -- 0x3C00 - 0x3FFF -> LED 15
        led_index      := to_integer(ram_wraddr(ram_wraddr'high downto ram_wraddr'high - 3));
        LED(led_index) <= '1';
        ram_we         <= '1';
        if ram_wraddr = RAM_SIZE - 1 then
          start_capture <= '0';
        end if;
      end if;
    end if;
  end process;

  ram : process(clk)
  begin
    if rising_edge(clk) then
      if ram_we then
        amplitude_store(to_integer(ram_wraddr)) <= amplitude;
      end if;
      ram_dout <= amplitude_store(to_integer(ram_rdaddr));
    end if;
  end process;

  -- Playback the audio
  pwm_outputs : entity work.pwm_outputs
    generic map(
      RAM_SIZE     => RAM_SIZE,
      CLK_FREQ     => CLK_FREQ,
      SAMPLE_COUNT => SAMPLE_COUNT,
      INPUT_FREQ   => INPUT_FREQ
    )
    port map(
      clk            => clk,
      start_playback => BTNU,
      ram_rdaddr     => ram_rdaddr,
      ram_sample     => ram_dout,
      AUD_PWM_en     => AUD_PWM_en,
      clr_led        => clr_led
    );

  AUD_PWM <= '0' when AUD_PWM_en else 'Z';

end architecture rtl;

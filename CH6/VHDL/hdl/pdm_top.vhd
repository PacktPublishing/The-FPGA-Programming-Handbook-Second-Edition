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

  constant RAM_SIZE_BITS : natural := clog2(RAM_SIZE);
  constant SAMPLE_BITS   : natural := clog2(SAMPLE_COUNT);

  type array_2d is array (natural range <>) of std_logic_vector(SAMPLE_BITS downto 0);

  signal amplitude_store : array_2d(0 to RAM_SIZE - 1); -- capture RAM
  signal ram_wraddr      : integer range 0 to RAM_SIZE - 1 := 0;
  signal ram_rdaddr      : integer range 0 to RAM_SIZE - 1 := 0;
  signal ram_we          : std_logic                       := '0';
  signal ram_dout        : std_logic_vector(SAMPLE_BITS downto 0);
  signal amplitude       : std_logic_vector(SAMPLE_BITS downto 0);
  signal amplitude_valid : std_logic;
  signal button_usync    : std_logic_vector(2 downto 0);
  signal button_csync    : std_logic_vector(2 downto 0);
  signal start_capture   : std_logic                       := '0';
  signal m_clk_en        : std_logic;
  signal m_clk_en_del    : std_logic;
  signal light_count     : integer range 0 to 127          := 0;
  signal start_playback  : std_logic                       := '0';
  signal clr_led         : std_logic_vector(15 downto 0)   := (others => '0');
  signal amp_capture     : std_logic_vector(6 downto 0);
  signal AUD_PWM_en      : std_logic;
  signal amp_counter     : integer range 0 to 127;
  signal clr_addr        : integer range 0 to 15;
  signal ram_rdaddr_u    : unsigned(RAM_SIZE_BITS - 1 downto 0);

  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of amplitude, amplitude_valid : signal is "TRUE";
  attribute ASYNC_REG  : string;
  attribute ASYNC_REG of button_usync, button_csync : signal is "TRUE";

begin
  AUD_SD   <= '1';
  m_lr_sel <= '0';

  u_pdm_inputs : entity work.pdm_inputs
    generic map(
      CLK_FREQ => CLK_FREQ
    )
    port map(
      clk             => clk,
      m_clk           => m_clk,
      m_clk_en        => m_clk_en,
      m_data          => m_data,
      amplitude       => amplitude,
      amplitude_valid => amplitude_valid);

  -- Display using tricolor LED
  process(clk)
  begin
    if rising_edge(clk) then
      if m_clk_en then
        light_count <= light_count + 1 when light_count < 127 else 0;
      end if;
      B <= '1' when (40 - unsigned(amplitude)) < light_count else '0';
      R <= '0';
      G <= '0';
    end if;
  end process;

  -- Capture the Audio data
  capture : process(clk)
    variable ram_wraddr_u : unsigned(RAM_SIZE_BITS - 1 downto 0);
    variable led_index    : integer range 0 to LED'high;
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
          ram_wraddr <= 0;
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
        ram_wraddr_u   := to_unsigned(ram_wraddr, ram_wraddr_u'length);
        led_index      := to_integer(ram_wraddr_u(ram_wraddr_u'high downto ram_wraddr_u'high - 3));
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
        amplitude_store(ram_wraddr) <= amplitude;
      end if;
      ram_dout <= amplitude_store(ram_rdaddr);
    end if;
  end process;

  ram_rdaddr_u <= to_unsigned(ram_rdaddr, RAM_SIZE_BITS);
  clr_addr     <= TO_INTEGER(ram_rdaddr_u(RAM_SIZE_BITS - 1 downto RAM_SIZE_BITS - 4));

  -- Playback the audio
  playback : process(clk)
  begin
    if rising_edge(clk) then
      button_usync <= button_usync(1 downto 0) & BTNU;
      m_clk_en_del <= m_clk_en;
      clr_led      <= (others => '0');

      if button_usync(2 downto 1) = "01" then
        start_playback <= '1';
        ram_rdaddr     <= 0;
      elsif start_playback and m_clk_en_del then
        clr_led(clr_addr) <= '1';
        AUD_PWM_en        <= '1';
        if amplitude_valid then
          ram_rdaddr  <= ram_rdaddr + 1;
          amp_counter <= 1;
          amp_capture <= ram_dout;
          if ram_dout /= 7d"0" then
            AUD_PWM_en <= '0';          -- Activate pull up
          end if;
        else
          amp_counter <= amp_counter + 1;
          if unsigned(amp_capture) < amp_counter then
            AUD_PWM_en <= '0';          -- Activate pull up
          end if;
        end if;
        if and ram_rdaddr_u then
          start_playback <= '0';
        end if;
      end if;
    end if;
  end process;

  AUD_PWM <= '0' when AUD_PWM_en else 'Z';

end architecture rtl;

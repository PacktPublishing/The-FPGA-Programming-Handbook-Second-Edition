-- tb_pdm_top.vhd
-- ------------------------------------
-- Test Bench for PDM
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- This module generates a PDM waveform and samples the same waveform.
-- The outputs can be visually verified. Please see the book for how to use it.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity tb_pdm_top is
end entity tb_pdm_top;

architecture rtl of tb_pdm_top is

  type u6_array_t is array (natural range <>) of unsigned(6 downto 0);

  constant CLK_FREQ     : integer := 100; -- MHz
  constant CLK_PERIOD   : time    := 1 sec / (CLK_FREQ * 1000000);
  constant RAM_SIZE     : natural := 16384; -- NOTE: reduce to e.g. 1024 for faster simulation
  constant SAMPLE_COUNT : natural := 128;
  constant SAMPLE_RATE  : natural := 25000; -- Hz

  constant SIN_TABLE : u6_array_t(0 to 127) := (
    7x"00", 7x"01", 7x"03", 7x"04",
    7x"06", 7x"07", 7x"09", 7x"0a",
    7x"0c", 7x"0d", 7x"0f", 7x"10",
    7x"12", 7x"13", 7x"15", 7x"16",
    7x"18", 7x"19", 7x"1a", 7x"1c",
    7x"1d", 7x"1f", 7x"20", 7x"21",
    7x"23", 7x"24", 7x"25", 7x"26",
    7x"27", 7x"29", 7x"2a", 7x"2b",
    7x"2c", 7x"2d", 7x"2e", 7x"2f",
    7x"30", 7x"31", 7x"32", 7x"33",
    7x"34", 7x"35", 7x"36", 7x"36",
    7x"37", 7x"38", 7x"38", 7x"39",
    7x"3a", 7x"3a", 7x"3b", 7x"3b",
    7x"3c", 7x"3c", 7x"3d", 7x"3d",
    7x"3d", 7x"3e", 7x"3e", 7x"3e",
    7x"3e", 7x"3e", 7x"3e", 7x"3e",
    7x"3f", 7x"3e", 7x"3e", 7x"3e",
    7x"3e", 7x"3e", 7x"3e", 7x"3e",
    7x"3d", 7x"3d", 7x"3d", 7x"3c",
    7x"3c", 7x"3b", 7x"3b", 7x"3a",
    7x"3a", 7x"39", 7x"38", 7x"38",
    7x"37", 7x"36", 7x"36", 7x"35",
    7x"34", 7x"33", 7x"32", 7x"31",
    7x"30", 7x"2f", 7x"2e", 7x"2d",
    7x"2c", 7x"2b", 7x"2a", 7x"29",
    7x"27", 7x"26", 7x"25", 7x"24",
    7x"23", 7x"21", 7x"20", 7x"1f",
    7x"1d", 7x"1c", 7x"1a", 7x"19",
    7x"18", 7x"16", 7x"15", 7x"13",
    7x"12", 7x"10", 7x"0f", 7x"0d",
    7x"0c", 7x"0a", 7x"09", 7x"07",
    7x"06", 7x"04", 7x"03", 7x"01");

  signal clk : std_logic := '0';

  -- Microphone interface
  signal m_clk    : std_logic;
  signal m_lr_sel : std_logic;
  signal m_data   : std_logic;

  -- Tricolor LED
  signal R, G, B : std_logic;

  -- Pushbutton interface
  signal BTNU : std_logic;
  signal BTNC : std_logic;

  -- LED Array
  signal LED : std_logic_vector(15 downto 0) := (others => '0');

  -- PDM output
  signal AUD_PWM : std_logic;
  signal AUD_SD  : std_logic;

  signal data_in : unsigned(6 downto 0) := (others => '0');

begin

  clk <= not clk after CLK_PERIOD / 2;

  u_pdm_top : entity work.pdm_top
    generic map(
      RAM_SIZE     => RAM_SIZE,
      CLK_FREQ     => CLK_FREQ,
      SAMPLE_COUNT => SAMPLE_COUNT
    )
    port map(
      clk      => clk,
      m_clk    => m_clk,
      m_lr_sel => m_lr_sel,
      m_data   => m_data,
      R        => R,
      G        => G,
      B        => B,
      BTNU     => BTNU,
      BTNC     => BTNC,
      LED      => LED,
      AUD_PWM  => AUD_PWM,
      AUD_SD   => AUD_SD);

  AUD_PWM <= 'H';                       -- simulate the pull-up on the board

  u_pdm_output : entity work.pdm_output
    port map(
      clk      => m_clk,
      data_in  => data_in,
      data_out => m_data
    );

  -- Test control
  test : process is
  begin
    BTNC <= '0';
    BTNU <= '0';
    for i in 1 to 10000 loop
      wait until rising_edge(clk);
    end loop;
    report "Start capture";
    BTNC <= '1';
    for i in 1 to 100 loop
      wait until rising_edge(clk);
    end loop;
    BTNC <= '0';
    wait until (and LED);               -- all LEDs ON -> last block is begin written to RAM
    wait for (real(RAM_SIZE) / real(LED'length * SAMPLE_RATE)) * 1 sec; -- wait until the last block has been captured
    report "Capture done";
    report "Start playback";
    BTNU <= '1';
    for i in 1 to 100 loop
      wait until rising_edge(clk);
    end loop;
    BTNU <= '0';
    wait until not (or LED);            -- all LEDs OFF -> last block is begin read from RAM
    for i in 1 to 10000 loop
      wait until rising_edge(clk);
    end loop;
    wait for (real(RAM_SIZE) / real(LED'length * SAMPLE_RATE)) * 1 sec; -- wait until the last block has been read
    report "Waveform has been sampled and played back. You can view waves.";
    std.env.stop;
  end process test;

  -- PDM generator
  process(m_clk)
    variable counter   : integer range 0 to 255 := 0;
    variable int_count : integer range 0 to 127 := 0;
  begin
    if rising_edge(m_clk) then
      if int_count = 127 then           -- Generate a new amplitude sample every 128 m_clk cycles
        if counter = 255 then
          counter := 0;
        else
          counter := counter + 1;
        end if;
        int_count := 0;                 -- Note: in VHDL, integers do not wrap so we need to make sure to handle this
      else
        int_count := int_count + 1;
      end if;
      if counter > 127 then
        data_in <= 64 + SIN_TABLE(counter - 128);
      else
        data_in <= 64 - SIN_TABLE(counter);
      end if;
    end if;
  end process;

end architecture;

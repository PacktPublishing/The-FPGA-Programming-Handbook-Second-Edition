-- pdm_inputs.vhd
-- ------------------------------------
-- Pulse Data Modulation input module
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- This module captures PDM data, in this case from a microphone.
-- It uses two sets of overlapping windowed data. Please see CH6
-- of the book for a detailed explanation.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pdm_inputs is
  generic(
    CLK_FREQ  : integer := 100;         -- MHz
    MCLK_FREQ : integer := 2400000      -- Hz
  );
  port(
    clk             : in  std_logic;
    -- Microphone interface
    m_clk           : out std_logic := '0';
    m_clk_en        : out std_logic := '0';
    m_data          : in  std_logic;
    -- Amplitude outputs
    amplitude       : out std_logic_vector(6 downto 0);
    amplitude_valid : out std_logic := '0'
  );
end entity pdm_inputs;

architecture rtl of pdm_inputs is

  constant CLK_COUNT       : integer := integer((CLK_FREQ * 1000000) / (MCLK_FREQ * 2));
  constant WINDOW_SIZE     : natural := 200; -- Size of a window
  constant COUNTER1_OFFSET : natural := 100; -- Offset value for counter 1
  constant TERMINAL_COUNT0 : natural := 128; -- Terminal Count for counter 1
  constant TERMINAL_COUNT1 : natural := 28; -- Terminal Count for counter 1

  type array_2d is array (natural range <>) of integer range 0 to 255;

  signal counter        : integer range 0 to WINDOW_SIZE - 1 := 0;
  signal sample_counter : array_2d(1 downto 0)               := (others => 0);
  signal clk_counter    : integer range 0 to CLK_COUNT - 1   := 0;

begin

  process(clk) is
  begin
    if rising_edge(clk) then
      -- Defaults:
      amplitude_valid <= '0';
      m_clk_en        <= '0';

      if clk_counter = CLK_COUNT - 1 then
        clk_counter <= 0;
        m_clk       <= not m_clk;
        m_clk_en    <= not m_clk;
      else
        clk_counter <= clk_counter + 1;
      end if;

      if m_clk_en then
        if counter < WINDOW_SIZE - 1 then
          counter <= counter + 1;
        else
          counter <= 0;
        end if;
        if counter = TERMINAL_COUNT0 then
          amplitude         <= std_logic_vector(to_unsigned(sample_counter(0), amplitude'length));
          amplitude_valid   <= '1';
          sample_counter(0) <= 0;
        elsif counter <= TERMINAL_COUNT0 - 1 then
          if m_data then
            sample_counter(0) <= sample_counter(0) + 1;
          end if;
        end if;
        if counter = TERMINAL_COUNT1 then
          amplitude         <= std_logic_vector(to_unsigned(sample_counter(1), amplitude'length));
          amplitude_valid   <= '1';
          sample_counter(1) <= 0;
        elsif (counter <= TERMINAL_COUNT1 - 1) or (counter >= COUNTER1_OFFSET) then
          if m_data then
            sample_counter(1) <= sample_counter(1) + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;

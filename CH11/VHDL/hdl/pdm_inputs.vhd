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

use work.util_pkg.all;

entity pdm_inputs is
  generic(
    CLK_FREQ     : natural := 100;      -- MHz
    MCLK_FREQ    : natural := 2500000;  -- Hz
    SAMPLE_COUNT : natural := 128
  );
  port(
    clk             : in  std_logic;
    -- Microphone interface
    m_clk           : out std_logic := '0';
    m_clk_en        : out std_logic := '0';
    m_data          : in  std_logic;
    -- Amplitude outputs
    amplitude       : out unsigned(6 downto 0);
    amplitude_valid : out std_logic := '0'
  );
end entity pdm_inputs;

architecture rtl of pdm_inputs is

  constant CLK_COUNT       : integer := (CLK_FREQ * 1000000) / (MCLK_FREQ * 2);
  constant WINDOW_SIZE     : natural := 200; -- Size of a window
  constant COUNTER1_OFFSET : natural := WINDOW_SIZE / 2; -- Offset value for counter 1
  constant TERMINAL_COUNT0 : natural := SAMPLE_COUNT; -- Terminal Count for counter 0
  constant TERMINAL_COUNT1 : natural := SAMPLE_COUNT - COUNTER1_OFFSET; -- Terminal Count for counter 1

  type sample_counter_array_t is array (natural range <>) of integer range 0 to SAMPLE_COUNT;

  signal counter        : integer range 0 to WINDOW_SIZE - 1 := 0;
  signal sample_counter : sample_counter_array_t(1 downto 0) := (others => 0);
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
          amplitude         <= to_unsigned(sample_counter(0), amplitude'length);
          amplitude_valid   <= '1';
          sample_counter(0) <= 0;
        elsif counter < TERMINAL_COUNT0 then
          if m_data then
            sample_counter(0) <= sample_counter(0) + 1;
          end if;
        end if;
        if counter = TERMINAL_COUNT1 then
          amplitude         <= to_unsigned(sample_counter(1), amplitude'length);
          amplitude_valid   <= '1';
          sample_counter(1) <= 0;
        elsif (counter < TERMINAL_COUNT1) or (counter >= COUNTER1_OFFSET) then
          if m_data then
            sample_counter(1) <= sample_counter(1) + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;

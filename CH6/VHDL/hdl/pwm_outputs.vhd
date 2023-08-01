-- pwm_outputs.vhd
-- ------------------------------------
-- Pulse Width Modulation output generation
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- This module reads from a memory and generates a PWM waveform.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.util_pkg.all;

entity pwm_outputs is
  generic(
    RAM_SIZE     : natural := 16384;    -- bytes
    CLK_FREQ     : natural := 100;      -- MHz
    SAMPLE_COUNT : natural := 128;      -- Number of samples
    INPUT_FREQ   : natural := 25000     -- Input waveform frequency in Hz
  );
  port(
    clk            : in  std_logic;
    start_playback : in  std_logic;
    -- RAM read interface
    ram_rdaddr     : out unsigned(clog2(RAM_SIZE) - 1 downto 0) := (others => '0');
    ram_sample     : in  std_logic_vector(clog2(SAMPLE_COUNT + 1) - 1 downto 0);
    -- PWM output
    AUD_PWM_en     : out std_logic                              := '1';
    -- LED clearing
    clr_led        : out std_logic_vector(15 downto 0)
  );
end entity pwm_outputs;

architecture RTL of pwm_outputs is

  constant CLK_COUNT   : natural := ((CLK_FREQ * 1000000) / (INPUT_FREQ * SAMPLE_COUNT));
  constant SAMPLE_BITS : natural := clog2(SAMPLE_COUNT + 1);

  -- Registered signals with initial values
  signal clk_counter    : natural range 0 to CLK_COUNT - 1           := 0;
  signal sample_counter : natural range 0 to SAMPLE_COUNT - 1        := 0;
  signal sample_valid   : std_logic                                  := '0';
  signal playback       : std_logic                                  := '0';
  signal start_sync     : std_logic_vector(2 downto 0)               := (others => '0');
  signal amp_capture    : std_logic_vector(SAMPLE_BITS - 1 downto 0) := (others => '0');

  -- Unregistered signals
  signal clr_addr : unsigned(3 downto 0);

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of start_sync : signal is "TRUE";

begin

  clr_addr <= unsigned(not ram_rdaddr(ram_rdaddr'high downto ram_rdaddr'high - 3));

  pwm : process(clk) is
  begin
    if rising_edge(clk) then

      clr_led    <= (others => '0');
      start_sync <= start_sync(start_sync'high - 1 downto 0) & start_playback;

      sample_valid <= '0';
      if clk_counter = CLK_COUNT - 1 then
        sample_valid <= '1';
        clk_counter  <= 0;
      else
        clk_counter <= clk_counter + 1;
      end if;

      if start_sync(2 downto 1) = "01" then -- Rising edge on start_playback
        playback       <= '1';
        ram_rdaddr     <= (others => '0');
        sample_counter <= 0;
        amp_capture    <= (others => '0');
      elsif playback and sample_valid then
        clr_led(to_integer(clr_addr)) <= '1';
        AUD_PWM_en                    <= '1';
        if sample_counter <= unsigned(amp_capture) then
          AUD_PWM_en <= '0';            -- Activate pull up
        end if;
        if sample_counter = SAMPLE_COUNT - 1 then
          -- We've generated a single audio sample
          sample_counter <= 0;
          if ram_rdaddr = RAM_SIZE - 1 then
            playback   <= '0';
            ram_rdaddr <= (others => '0');
          end if;
        else
          sample_counter <= sample_counter + 1;
          if sample_counter = 0 then
            ram_rdaddr <= ram_rdaddr + 1; -- We are capturing the previous sample
            if unsigned(ram_sample) > 0 then
              AUD_PWM_en <= '0';        -- Activate pull up
            end if;
            amp_capture <= ram_sample;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture RTL;

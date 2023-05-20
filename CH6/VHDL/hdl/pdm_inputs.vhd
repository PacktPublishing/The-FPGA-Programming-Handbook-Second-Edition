library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity pdm_inputs is
  generic (CLK_FREQ     : integer := 100;      -- Mhz
           SAMPLE_RATE  : integer := 2400000); -- Hz
  port (clk         : in std_logic;

        -- Microphone interface
        m_clk       : out std_logic := '0';
        m_clk_en    : out std_logic := '0';
        m_data      : in std_logic;

        -- amplitude outputs
        amplitude   : out std_logic_vector(6 downto 0) := 7d"0";
        amplitude_valid : out std_logic);
end entity pdm_inputs;

architecture rtl of pdm_inputs is
  constant CLK_COUNT : integer := integer((CLK_FREQ*1000000) / SAMPLE_RATE);

  type array_2d is array (natural range <>) of integer range 0 to 255;
  signal counter0 : integer range 0 to 127 := 0;
  signal counter1 : integer range 0 to 127 := 64;
  signal sample_counter : array_2d(1 downto 0) := (others => 0);
  signal clk_counter : integer range 0 to CLK_COUNT := 0;
  signal amplitude_int : unsigned(6 downto 0);
begin

  amplitude <= std_logic_vector(amplitude_int);

  process (clk)
    variable nextamp0 : integer range 0 to 128;
    variable nextamp1 : integer range 0 to 128;
  begin

    if rising_edge(clk) then
      -- place this within the clocked portion to prevent possible latches.
      if m_data then
        nextamp0 := sample_counter(0) + 1;
        nextamp1 := sample_counter(1) + 1;
      else
        nextamp0 := sample_counter(0);
        nextamp1 := sample_counter(1);
      end if;
      amplitude_valid <= '0';
      m_clk_en        <= '0';

      if clk_counter = CLK_COUNT - 1 then
        clk_counter <= 0;
        m_clk       <= not m_clk;
        m_clk_en    <= not m_clk;
      else
        clk_counter <= clk_counter + 1;
        if clk_counter = CLK_COUNT - 2 then
          m_clk_en    <= not m_clk;
        end if;
      end if;

      if m_clk_en then
        if counter0 = 127 then
          counter0        <= 0;
          if nextamp0 <= 127 then
            amplitude_int <= to_unsigned(nextamp0, amplitude_int'length);
          else
            amplitude_int <= to_unsigned(127, amplitude_int'length);
          end if;
          amplitude_valid   <= '1';
          sample_counter(0) <= 0;
        else
          counter0          <= counter0 + 1;
          sample_counter(0) <= sample_counter(0) + 1 when m_data else sample_counter(0);
        end if;
        if counter1 = 127 then
          counter1        <= 0;
          if nextamp1 <= 127 then
            amplitude_int <= to_unsigned(nextamp1, amplitude_int'length);
          else
            amplitude_int <= to_unsigned(127, amplitude_int'length);
          end if;
          amplitude_valid   <= '1';
          sample_counter(1) <= 0;
        else
          counter1          <= counter1 + 1;
          sample_counter(1) <= sample_counter(1) + 1 when m_data else sample_counter(1);
        end if;
      end if;
    end if;
  end process;
end architecture rtl;

LIBRARY IEEE, XPM;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_UNSIGNED.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use XPM.vcomponents.all;

entity debounce is
  generic(CYCLES : integer := 16);
  port(clk     : in  std_logic;
       reset   : in  std_logic;
       sig_in  : in  std_logic;
       sig_out : out std_logic);
end entity debounce;
architecture rtl of debounce is
  attribute ASYNC_REG : string;
  signal cycle_count : integer range 0 to CYCLES := 0;
  signal current_state : std_logic := '0';
  signal sig_in_sync   : std_logic_vector(1 downto 0) := "00";
  attribute ASYNC_REG of sig_in_sync : signal is "TRUE";
  signal sig_out_r : std_logic := '0';
begin
  sig_out <= sig_out_r;
  process (clk)
  begin
    if rising_edge(clk) then
      sig_in_sync <= sig_in_sync(0) & sig_in;
      if sig_in_sync(1) /= current_state then
        current_state            <= sig_in_sync(1);
        cycle_count              <= 0;
      elsif cycle_count = CYCLES then
        cycle_count            <= 0;
        sig_out_r              <= current_state;
      else
        cycle_count            <= cycle_count + 1;
      end if;
      if reset then
        current_state <= '0';
        cycle_count   <= 0;
        sig_out_r     <= '0';
      end if;
    end if;
  end process;
end architecture rtl;

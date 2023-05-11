library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity leading_ones is
  generic(SELECTOR : string := "CASE";
          BITS : integer := 16);
  port(SW: in std_logic_vector(BITS-1 downto 0);
       LED: out std_logic_vector(natural(log2(real(BITS))) downto 0));
end entity leading_ones;

architecture rtl of leading_ones is
begin
  proc : process (all)
    variable lo : std_logic_vector(natural(log2(real(BITS))) downto 0);
  begin
    lo := (others => '0');
    -- Using CASE with variable sized input doesn't seem to easily be possible.
    if SELECTOR="DOWN_FOR" then
      for i in SW'range loop
        if SW(i) then
          lo := std_logic_vector(TO_UNSIGNED(i + 1, LED'length));
          exit;
        end if;
      end loop;
    elsif SELECTOR="UP_FOR" then
      for i in SW'reverse_range loop
        if SW(i) then
          lo := std_logic_vector(TO_UNSIGNED(i + 1, LED'length));
        end if;
      end loop;
    end if;
    LED <= lo;
  end process proc;
end architecture rtl;

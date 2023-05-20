-- num_ones.vhd
-- ------------------------------------
-- Count the number of bits that are high in a vector
-- ------------------------------------
-- Author : Frank Bruno
-- Count the number of bits that are high in a vector
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity num_ones is
  generic(BITS : integer := 16);
  port(SW: in std_logic_vector(BITS-1 downto 0);
       LED: out std_logic_vector(natural(log2(real(BITS))) downto 0));
end entity num_ones;

architecture rtl of num_ones is
begin

  counter : process (all)
    variable count : unsigned(natural(log2(real(BITS))) downto 0);
  begin
    count := (others => '0');
    for i in SW'range loop
      count := count + SW(i);
    end loop;
    LED <= std_logic_vector(count);
  end process counter;
end architecture rtl;

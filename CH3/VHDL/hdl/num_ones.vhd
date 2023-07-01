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
  generic(
    BITS : integer := 16
  );
  port(
    SW  : in  std_logic_vector(BITS - 1 downto 0);
    LED : out std_logic_vector(natural(ceil(log2(real(BITS)))) downto 0)
  );
end entity num_ones;

architecture rtl of num_ones is
begin

  counter : process(all)
    variable count : natural range 0 to BITS;
  begin
    count := 0;
    for i in SW'range loop
      if SW(i) then
        count := count + 1;
      end if;
    end loop;
    LED   <= std_logic_vector(to_unsigned(count, LED'length));
  end process counter;

end architecture rtl;

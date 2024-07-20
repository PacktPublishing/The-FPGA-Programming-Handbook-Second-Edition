-- leading_ones.vhd
-- ------------------------------------
-- Leading ones detector module
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- Find the leading ones (highest bit set) in a vector.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity leading_ones is
  generic(
    SELECTOR : string  := "CASE";
    BITS     : integer := 16
  );
  port(
    SW  : in  std_logic_vector(BITS - 1 downto 0);
    LED : out std_logic_vector(natural(ceil(log2(real(BITS)))) downto 0)
  );
end entity leading_ones;

architecture rtl of leading_ones is
begin

  proc : process(all)
    variable lo : natural range 0 to BITS;
  begin
    lo  := 0;
    -- Using CASE with variable sized input doesn't seem to easily be possible.
    if SELECTOR = "DOWN_FOR" then
      for i in SW'high downto SW'low loop
        if SW(i) then
          lo := i + 1;
          exit;
        end if;
      end loop;
    else
      for i in SW'low to SW'high loop
        if SW(i) then
          lo := i + 1;
        end if;
      end loop;
    end if;
    LED <= std_logic_vector(to_unsigned(lo, LED'length));
  end process proc;

end architecture rtl;

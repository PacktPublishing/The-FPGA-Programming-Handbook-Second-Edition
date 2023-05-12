LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.std_logic_UNSIGNED.all;
USE ieee.numeric_std.all;
USE WORK.counting_buttons_pkg.all;

PACKAGE temp_pkg IS
  constant NUM_SEGMENTS : integer := 8;
  function bin_to_bcd (bin_in : in std_logic_vector(31 downto 0)) return array_t;
end package temp_pkg;

package body temp_pkg is 
  function bin_to_bcd (bin_in : in std_logic_vector(31 downto 0)) return array_t is
    variable shifted : std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
    variable bin2bcd : array_t(NUM_SEGMENTS -1 downto 0)(3 downto 0);
  begin
    
    shifted := (others => '0');
    shifted(1 downto 0) := bin_in(31 downto 30);
    for i in 29 downto 1 loop
      shifted := shifted(30 downto 0) & bin_in(i);
      for j in 0 to NUM_SEGMENTS-1 loop
        if shifted(j*4+3 downto j*4) > 4 then
          shifted(j*4+3 downto j*4) := shifted(j*4+3 downto j*4) + 3;
        end if;
      end loop;
    end loop;
    shifted := shifted(30 downto 0) & bin_in(0);
    for i in 0 to NUM_SEGMENTS - 1 loop
      bin2bcd(i) := shifted(4*i+3 downto 4*i);
    end loop;
    return bin2bcd;
  end function bin_to_bcd;

end package body temp_pkg;
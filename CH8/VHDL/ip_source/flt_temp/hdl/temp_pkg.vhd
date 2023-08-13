-- temp_pkg.vhd
-- ------------------------------------
-- Package for I2C temperature sensor interface
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- This file supports the temperature sensor project, provides a binary to BCD conversion function

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE ieee.numeric_std.all;

use work.util_pkg.all; -- slv4_array_t

package temp_pkg IS

  function bin_to_bcd(bin_in : in std_logic_vector(31 downto 0); num_segments : in natural) return slv4_array_t;

end package temp_pkg;

package body temp_pkg is

  function bin_to_bcd(bin_in : in std_logic_vector(31 downto 0); num_segments : in natural) return slv4_array_t is
    variable shifted : unsigned(num_segments * 4 - 1 downto 0);
    variable bin2bcd : slv4_array_t(num_segments - 1 downto 0);
  begin

    shifted             := (others => '0');
    shifted(1 downto 0) := unsigned(bin_in(31 downto 30));
    for i in 29 downto 1 loop
      shifted := shifted(30 downto 0) & bin_in(i);
      for j in 0 to num_segments - 1 loop
        if shifted(j * 4 + 3 downto j * 4) > 4 then
          shifted(j * 4 + 3 downto j * 4) := shifted(j * 4 + 3 downto j * 4) + 3;
        end if;
      end loop;
    end loop;
    shifted             := shifted(30 downto 0) & bin_in(0);
    for i in 0 to num_segments - 1 loop
      bin2bcd(i) := std_logic_vector(shifted(4 * i + 3 downto 4 * i));
    end loop;
    return bin2bcd;
  end function bin_to_bcd;

end package body temp_pkg;

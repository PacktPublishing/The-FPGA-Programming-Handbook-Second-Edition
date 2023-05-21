-- calculator_pkg.vhd
-- ------------------------------------
-- Package for the calculator project
-- ------------------------------------
-- Author : Frank Bruno
-- defines constants to represent button indices.
-- bin_to_bcd function
LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
USE WORK.counting_buttons_pkg.all;

PACKAGE calculator_pkg IS
  constant NUM_SEGMENTS : integer := 8;
  constant UP           : natural := 0;
  constant DOWN         : natural := 1;
  constant LEFT         : natural := 2;
  constant RIGHT        : natural := 3;
  constant CENTER       : natural := 4;
  function bin_to_bcd (bin_in : in std_logic_vector(31 downto 0)) return array_t;
end package calculator_pkg;

package body calculator_pkg is
  function bin_to_bcd (bin_in : in std_logic_vector(31 downto 0)) return array_t is
    variable shifted : std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
    variable bin2bcd : array_t(NUM_SEGMENTS -1 downto 0)(3 downto 0);
    variable digit   : integer range 0 to 15;
  begin

    shifted := (others => '0');
    shifted(1 downto 0) := bin_in(31 downto 30);
    for i in 29 downto 1 loop
      shifted := shifted(30 downto 0) & bin_in(i);
      for j in 0 to NUM_SEGMENTS-1 loop
        digit := to_integer(unsigned(shifted(j*4+3 downto j*4)));
        if digit > 4 then
          shifted(j*4+3 downto j*4) := std_logic_vector(to_unsigned(digit + 3, 4));
        end if;
      end loop;
    end loop;
    shifted := shifted(30 downto 0) & bin_in(0);
    for i in 0 to NUM_SEGMENTS - 1 loop
      bin2bcd(i) := shifted(4*i+3 downto 4*i);
    end loop;
    return bin2bcd;
  end function bin_to_bcd;
end package body calculator_pkg;

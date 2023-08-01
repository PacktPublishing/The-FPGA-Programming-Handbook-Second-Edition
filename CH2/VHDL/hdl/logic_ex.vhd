-- logic_ex.vhd
-- ------------------------------------
-- Example file to show combinational functions
-- ------------------------------------
-- Author : Frank Bruno
-- This file demonstrates combinational LED outputs based upon switch inputs.
-- There are multiple ways of accomplishing each function, uncomment to try them

library IEEE;
use IEEE.std_logic_1164.all;

entity logic_ex is
  port(
    SW  : in  std_logic_vector(1 downto 0);
    LED : out std_logic_vector(3 downto 0)
  );
end entity logic_ex;

architecture rtl of logic_ex is
begin

  LED(0) <= not SW(0);

  LED(1) <= SW(1) and SW(0);
  --LED(1)  <= and(SW); -- VHDL 2008

  LED(2) <= SW(1) or SW(0);
  --LED(2)  <= or(SW); -- VHDL 2008

  LED(3) <= SW(1) xor SW(0);
  --LED(3)  <= xor(SW); -- VHDL 2008

end architecture rtl;

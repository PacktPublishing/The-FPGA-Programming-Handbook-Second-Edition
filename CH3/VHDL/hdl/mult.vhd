-- mult.vhd
-- ------------------------------------
-- Multiplier
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- Take a vector, split in half and multiply the two halves together.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity mult is
  generic(
    BITS : integer := 16
  );
  port(
    SW  : in  std_logic_vector(BITS - 1 downto 0);
    LED : out std_logic_vector(BITS - 1 downto 0)
  );
end entity mult;

architecture rtl of mult is
begin

  multiplier : process(all)
    variable a_in   : signed(BITS / 2 - 1 downto 0);
    variable b_in   : signed(BITS / 2 - 1 downto 0);
    variable result : signed(BITS - 1 downto 0);
  begin
    a_in   := signed(SW(BITS - 1 downto BITS / 2));
    b_in   := signed(SW(BITS / 2 - 1 downto 0));
    result := a_in * b_in;
    LED    <= std_logic_vector(result);
  end process multiplier;

end architecture rtl;

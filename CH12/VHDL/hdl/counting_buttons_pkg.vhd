-- counting_buttons_pkg.vhd
-- ------------------------------------
-- Package to hold our array type
-- ------------------------------------
-- Author : Frank Bruno
library IEEE;
use IEEE.std_logic_1164.all;
package counting_buttons_pkg is
  type array_t is array (natural range <>) of std_logic_vector;

end package counting_buttons_pkg;

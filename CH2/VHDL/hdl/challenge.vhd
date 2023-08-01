-- challenge.vhd
-- ------------------------------------
--  Chapter 2 Challenge Template
-- ------------------------------------
-- Author : Frank Bruno
-- This file is a template for writing a full adder

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity challenge is
  port(
    SW  : in  std_logic_vector(2 downto 0);
    LED : out std_logic_vector(1 downto 0)
  );
end entity challenge;

architecture rtl of challenge is
begin
  -- SW[2] is carry in
  -- SW[1] is A
  -- SW[0] is B
  LED(0) <= '0';                        -- Write the code for the Sum
  LED(1) <= '0';                        -- Write the code for the Carry

end architecture rtl;

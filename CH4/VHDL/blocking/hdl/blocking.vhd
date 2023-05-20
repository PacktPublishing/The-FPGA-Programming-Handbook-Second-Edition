-- blocking.vhd
-- ------------------------------------
-- Example file to show blocking assignments
-- ------------------------------------
-- Author : Frank Bruno
-- This file demonstrates potential problems and differences between blocking
-- and non blocking assignment
library IEEE;
use IEEE.std_logic_1164.all;
entity blocking is
  generic (blocking : string := "FALSE");
  port (D : in std_logic; CK : in std_logic; Q : out std_logic);
end entity blocking;
architecture rtl of blocking is
  signal reg : std_logic := '0'; -- optional initial value
  signal reg_stage : std_logic := '0'; -- optional initial value
begin
  FF : process (CK)
    variable stage : std_logic := '0';
  begin
    if CK'event and CK='1' then
      if blocking = "TRUE" then
        stage := D; -- equivalent to non blocking
        reg <= stage;
      else
        reg_stage <= D;
        reg <= reg_stage;
      end if;
    end if;
  end process FF;
  Q <= reg;
end architecture rtl;

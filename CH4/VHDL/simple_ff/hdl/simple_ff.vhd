-- simple_ff.vhd
-- ------------------------------------
-- Example Simple Flip Flop inference
-- ------------------------------------
-- Author : Frank Bruno
-- Infer a simple FF
library IEEE;
use IEEE.std_logic_1164.all;
entity simple_ff is
  port (D : in std_logic; CK : in std_logic; Q : out std_logic);
end entity simple_ff;
architecture rtl of simple_ff is
  signal reg : std_logic := '0'; -- optional initial value
begin
  FF : process (CK)
  begin
    if CK'event and CK='1' then reg <= D; end if;
    -- The following is equivalent:
    -- if rising_edge(CK) then reg <= D; end if;
  end process FF;
  Q <= reg;
end architecture rtl;

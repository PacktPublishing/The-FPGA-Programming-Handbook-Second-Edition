-- tb.vhd
-- ------------------------------------
-- Testbench for the blocking assignment example
-- ------------------------------------
-- Author : Frank Bruno
-- Non self checking testbench for the blocking assignment to demonstrate the
-- fallthrough of data when using blocking in a chain of registers.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use std.env.finish;
entity tb_blocking is
  generic(blocking_ff : string := "FALSE");
end entity tb_blocking;
architecture tb of tb_blocking is
  signal CK : std_logic := '0';
  signal D : std_logic;
  signal Q : std_logic;
begin

  u0 : entity work.blocking
    generic map (BLOCKING => BLOCKing_ff)
    port map(CK => CK, D => D, Q => Q);

  clk : process
  begin
    while true loop
      CK <= not CK;
      wait for 100 ns;
    end loop;
  end process clk;

  chk : process
  begin
    D  <= '0';
    wait for 5 * 200 ns;
    wait for 1 ns; -- we add a ns to avoid a race between the clock edge and the D signal
    D  <= '1';
    wait for 200 ns;
    D  <= '0';
    wait for 200 ns;
    D  <= '1';
    wait for 200 ns;
    D  <= '0';
    wait for 200 ns;
    finish;
  end process chk;
end architecture tb;

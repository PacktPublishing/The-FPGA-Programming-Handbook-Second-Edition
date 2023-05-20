-- tb_simple_ff.vhd
-- ------------------------------------
-- Generate a test to lok at the simple_ff waveforms
-- ------------------------------------
-- Author : Frank Bruno
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use std.env.finish;
entity tb_simple_ff is
end entity tb_simple_ff;
architecture tb of tb_simple_ff is
  signal CK : std_logic := '0';
  signal CE : std_logic;
  signal D : std_logic;
  signal Q : std_logic;
begin

  u0 : entity work.simple_ff port map(CK => CK, D => D, Q => Q);

  clk : process
  begin
    while true loop
      CK <= not CK;
      wait for 100 ns;
    end loop;
  end process clk;

  chk : process
  begin
    CE <= '0';
    D  <= '0';
    wait for 5 * 200 ns;
    wait for 1 ns; -- we add a ns to avoid a race between the clock edge and the D signal
    D  <= '1';
    wait for 200 ns;
    D  <= '0';
    wait for 200 ns;
    CE <= '1';
    D  <= '1';
    wait for 200 ns;
    D  <= '0';
    wait for 200 ns;
    finish;
  end process chk;
end architecture tb;

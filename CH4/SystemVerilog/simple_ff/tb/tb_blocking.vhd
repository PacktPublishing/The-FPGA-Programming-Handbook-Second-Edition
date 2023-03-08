library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use std.env.finish;
entity tb is
  generic(blocking_ff : string := "FALSE");
end entity tb;
architecture tb of tb is
  signal CK : std_logic := '0';
  signal D : std_logic;
  signal Q : std_logic;
  component blocking is
    generic (blocking : string := "FALSE");
    port (D : in std_logic; CK : in std_logic; Q : out std_logic);
  end component blocking;

begin

  u0 : blocking
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

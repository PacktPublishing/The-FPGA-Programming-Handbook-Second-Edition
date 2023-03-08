library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use std.env.finish;
entity tb is
  generic (ASYNC : string := "true");
end entity tb;
architecture tb of tb is
  signal CK : std_logic := '0';
  signal CE : std_logic;
  signal SR : std_logic := '0';
  signal D : std_logic;
  signal Q : std_logic;
  component simple_ff_async is
    generic (ASYNC : string := "true");
    port (D : in std_logic; SR : in std_logic; CE : in std_logic;
          CK : in std_logic; Q : out std_logic);
  end component simple_ff_async;

begin

  u0 : simple_ff_async
    generic map (ASYNC => ASYNC)
    port map(D => D, SR => SR, CE => CE, CK => CK, Q => Q);

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
    SR <= '0';
    wait for 300 ns;
    SR <= '1';
    wait for 300 ns;
    SR <= '0';
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

-- tb.vhd
-- ------------------------------------
-- Testbench for Challenge problem
-- ------------------------------------
-- Author : Frank Bruno
-- Simple testbench to test your challenge problem
library IEEE, STD;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity tb is
end entity tb;

architecture tb of tb is

  -- Declare the components
  component challenge is
    port (SW: in std_logic_vector(2 downto 0);
          LED: out std_logic_vector(1 downto 0));
  end component logic_ex;

  -- define the signals
  signal SW: std_logic_vector(2 downto 0);
  signal LED: std_logic_vector(1 downto 0);
  signal SUM: std_logic_vector(1 downto 0);
  signal passed : std_logic := '1';

begin

  -- instantiate the module to be tested
  u_challenge: challenge port map (
    SW => SW,
    LED => LED);

  -- Stimulus
  -- Equivalent to the initial block in SV
  initial : process
  begin
    SW <= "000";
    for i in 0 to 8 loop
      SW(2 downto 0) <= std_logic_vector(to_unsigned(i, SW'length));
      report "setting SW to " & to_string(SW);
      wait for 100 ns;
    end loop;
    if ?? passed then
      report "PASS: logic_ex test PASSED!";
    else
      report "Failed!";
    end if;
    wait;
  end process initial;

  -- Checking
  SUM <= SW(0) + SW(1) + SW(2);
  checking : process (LED)
  begin
    if SUM /= SW then
      report "FAIL: Addition mismatch";
      passed <= '0';
    end if;
  end process checking;
end architecture tb;

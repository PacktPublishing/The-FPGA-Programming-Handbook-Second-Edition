-- tb.vhd
-- ------------------------------------
-- Testbench for logic_ex
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- Exhaustively test all combinations for the logic_ex module

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb is
end entity tb;

architecture tb of tb is

  -- Define the signals
  signal SW  : std_logic_vector(1 downto 0);
  signal LED : std_logic_vector(3 downto 0);

begin

  -- Instantiate the module to be tested
  u_logic_ex : entity work.logic_ex
    port map(
      SW  => SW,
      LED => LED
    );

  -- Stimulus
  -- Equivalent to the initial block in SV
  initial : process
  begin
    SW <= "00";
    for i in 0 to 3 loop
      SW <= std_logic_vector(to_unsigned(i, SW'length));
      report "setting SW to " & to_string(to_unsigned(i, SW'length));
      wait for 100 ns;
    end loop;
    report "PASS: logic_ex test PASSED!";
    std.env.stop;
    wait;
  end process initial;

  -- Checking
  checking : process
  begin
    wait until LED'event;
    if not SW(0) /= LED(0) then
      report "FAIL: NOT Gate mismatch" severity failure;
    end if;
    if and SW /= LED(1) then
      report to_string(and SW);
      report "FAIL: AND Gate mismatch" severity failure;
    end if;
    if or SW /= LED(2) then
      report "FAIL: OR Gate mismatch" severity failure;
    end if;
    if xor SW /= LED(3) then
      report "FAIL: XOR Gate mismatch" severity failure;
    end if;
  end process checking;

end architecture tb;

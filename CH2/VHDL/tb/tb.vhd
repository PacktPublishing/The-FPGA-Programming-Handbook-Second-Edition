library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.numeric_std.all;

entity tb is
end entity tb;

architecture tb of tb is

  -- Declare the components
  component logic_ex is
    port (SW: in std_logic_vector(1 downto 0);
          LED: out std_logic_vector(3 downto 0));
  end component logic_ex;

  -- define the signals
  signal SW: std_logic_vector(1 downto 0);
  signal LED: std_logic_vector(3 downto 0);
  signal passed : std_logic := '1';
  
begin

  -- instantiate the module to be tested
  u_logic_ex: logic_ex port map (
    SW => SW,
    LED => LED);

  -- Stimulus
  -- Equivalent to the initial block in SV
  initial : process
  begin
    SW <= "00";
    for i in 0 to 4 loop
      SW(1 downto 0) <= std_logic_vector(to_unsigned(i, SW'length));
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
  checking : process (LED)
  begin
    if not(SW(0)) /= LED(0) then
      report "FAIL: NOT Gate mismatch";
      passed <= '0';
    end if;
    if and_reduce(SW) /= LED(1) then
      report "FAIL: AND Gate mismatch";
      passed <= '0';
    end if;
    if or_reduce(SW) /= LED(2) then
      report "FAIL: OR Gate mismatch";
      passed <= '0';
    end if;
    if xor_reduce(SW) /= LED(3) then
      report "FAIL: XOR Gate mismatch";
      passed <= '0';
    end if;
  end process checking;
end architecture tb;

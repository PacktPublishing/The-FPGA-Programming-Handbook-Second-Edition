-- tb_divider_nr.vhd
-- ------------------------------------
-- Divider testbench
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- random testbench for the divider function - self checking

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity tb is
end entity tb;

architecture tb of tb is

  procedure wait_nclk(signal clk : std_ulogic; n : positive) is
  begin
    for i in 1 to n loop
      wait until rising_edge(clk);
    end loop;
  end procedure wait_nclk;

  constant BITS : integer := 16;

  signal clk       : std_logic := '0';
  signal reset     : std_logic := '0';
  signal start     : std_logic;
  signal dividend  : unsigned(BITS - 1 downto 0);
  signal divisor   : unsigned(BITS - 1 downto 0);
  signal done      : std_logic;
  signal quotient  : unsigned(BITS - 1 downto 0);
  signal remainder : unsigned(BITS - 1 downto 0);
begin

  clk <= not clk after 5 ns;

  u_divider_nr : entity work.divider_nr
    generic map(
      BITS => BITS
    )
    port map(
      clk       => clk,
      reset     => reset,
      start     => start,
      dividend  => dividend,
      divisor   => divisor,
      done      => done,
      quotient  => quotient,
      remainder => remainder
    );

  stim : process
    variable seed1, seed2 : positive;   -- seed values for random number generator
    variable rand_val     : real;       -- random real value 0 to 1.0
  begin
    start    <= '0';
    dividend <= (others => '0');
    divisor  <= (others => '0');

    wait_nclk(clk, 5);                  -- equivalent to repeat (5) @(posedge clk); in SV

    dividend <= 16d"11";
    divisor  <= 16d"3";
    start    <= '1';
    wait until rising_edge(clk);
    start    <= '0';
    wait on clk until rising_edge(clk) and done = '1';

    wait_nclk(clk, 5);

    for i in 0 to 99 loop
      uniform(seed1, seed2, rand_val);  -- generate random number
      dividend <= to_unsigned(integer(trunc(rand_val * 65536.0)), dividend'length);
      uniform(seed1, seed2, rand_val);  -- generate random number
      divisor  <= to_unsigned(integer(trunc(rand_val * 65536.0)), dividend'length);
      start    <= '1';
      wait until rising_edge(clk);
      start    <= '0';
      wait on clk until rising_edge(clk) and done = '1';
      wait_nclk(clk, 5);
    end loop;

    wait_nclk(clk, 10);

    std.env.stop;
  end process stim;

  check : process
    variable divd : integer;
    variable divi : integer;
  begin
    wait on clk until rising_edge(clk) and done = '1';
    divd := to_integer(unsigned(dividend));
    divi := to_integer(unsigned(divisor));
    report "Check: " & to_string(divd) & " / " & to_string(divi);
    assert (to_integer(quotient) = (divd / divi)) and (to_integer(remainder) = (divd mod divi))
    report "FAILURE!" & LF & "quotient:   " & to_string(to_integer(quotient)) & LF & "remainder:  " & to_string(to_integer(remainder)) & LF & "expected Q: " & to_string(divd / divi) & LF & "expected R: " & to_string(divd mod divi) severity failure;
  end process check;

end architecture tb;

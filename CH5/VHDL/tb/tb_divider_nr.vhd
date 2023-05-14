library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use std.env.finish;
entity tb is
end entity tb;
architecture tb of tb is
  procedure wait_nclk(signal clk: std_ulogic; n: positive) is
  begin
    for i in 1 to n loop
      wait until rising_edge(clk);
    end loop;
  end procedure wait_nclk;
  constant BITS : integer := 16;
  signal clk       : std_logic := '0';
  signal reset     : std_logic := '0';
  signal start     : std_logic;
  signal dividend  : std_logic_vector(BITS-1 downto 0);
  signal divisor   : std_logic_vector(BITS-1 downto 0);
  signal done      : std_logic;
  signal quotient  : std_logic_vector(BITS-1 downto 0);
  signal remainder : std_logic_vector(BITS-1 downto 0);
begin

  clock : process
  begin
    while true loop
      clk <= not clk;
      wait for 5 ns;
    end loop;
  end process clock;

  u_divider_nr : entity work.divider_nr
    generic map(BITS =>BITS)
    port map(clk       => clk,
             reset     => reset,
             start     => start,
             dividend  => dividend,
             divisor   => divisor,
             done      => done,
             quotient  => quotient,
             remainder => remainder);

  stim : process
    variable seed1, seed2: positive;  -- seed values for random number generator
    variable rand_val: real;              -- random real value 0 to 1.0
  begin
    start    <= '0';
    dividend <= (others => '0');
    divisor  <= (others => '0');
    wait_nclk(clk, 5); -- equivalent to repeat (5) @(posedge clk); in SV

    dividend <= 0x"000b";
    divisor  <= 0x"0003";
    start    <= '1';
    wait until rising_edge(clk);
    start    <= '0';
    while not(done) loop
      wait until rising_edge(clk);
    end loop;
    wait_nclk(clk, 5); -- equivalent to repeat (5) @(posedge clk); in SV
    for i in 0 to 99 loop
      uniform(seed1, seed2, rand_val);              -- generate random number
      dividend <= std_logic_vector(to_unsigned(integer(trunc(rand_val*65536.0)), dividend'length));
      uniform(seed1, seed2, rand_val);              -- generate random number
      divisor  <= std_logic_vector(to_unsigned(integer(trunc(rand_val*65536.0)), dividend'length));
      start    <= '1';
      wait until rising_edge(clk);
      start    <= '0';
      while not(done) loop
        wait until rising_edge(clk);
      end loop;
      wait_nclk(clk, 5); -- equivalent to repeat (5) @(posedge clk); in SV
    end loop;
    -- test divide by 0
    -- VHDL isn't as forgiving as SV so skipping this test
    --dividend <= (others => '0');
    --divisor  <= (others => '0');
    --start    <= '1';
    --wait until rising_edge(clk);
    --start    <= '0';
    --while not(done) loop
    --  wait until rising_edge(clk);
    --end loop;
    wait_nclk(clk, 10); -- equivalent to repeat (10) @(posedge clk); in SV
    finish;
  end process stim;

  check : process (clk)
    variable divd : integer;
    variable divi : integer;
  begin
    divd := to_integer(unsigned(dividend));
    divi := to_integer(unsigned(divisor));
    if rising_edge(clk) then
      if done = '1' and
        (quotient /= std_logic_vector(to_unsigned(divd/divi, quotient'length))) and
        (remainder /= std_logic_vector(to_unsigned(divd mod divi, remainder'length))) then
        report "FAILURE!";
        report "quotient:   " & to_string(quotient);
        report "remainder:  " & to_string(remainder);
        report "Expected Q: " & to_string(divd/divi);
        report "Expected R: " & to_string(divd mod divi);
      end if;
    end if;
  end process check;
end architecture tb;

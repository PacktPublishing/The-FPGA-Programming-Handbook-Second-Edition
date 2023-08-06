-- tb_parallel.vhd
-- ------------------------------------
-- Testbench for the parallel.vhd component
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.counting_buttons_pkg.all;

entity tb_parallel is
end entity tb_parallel;

architecture RTL of tb_parallel is

  constant CLK_PERIOD : time    := 10 ns;
  constant ITERATIONS : natural := 100; -- number of input vectors to generate

  type s40_array_t is array (natural range <>) of signed(39 downto 0);

  signal clk               : std_logic := '0';
  signal in_data           : array_t(255 downto 0)(31 downto 0);
  signal in_valid          : std_logic;
  signal out_data          : std_logic_vector(39 downto 0);
  signal out_valid         : std_logic;
  signal expected_out_data : s40_array_t(0 to ITERATIONS - 1);

begin

  clk <= not clk after CLK_PERIOD / 2;

  -- Generate stimulus data
  stimulus : process is
    constant MAX_DELAY    : natural := 3;
    variable rand_real    : real;
    variable rand_data    : integer;
    variable rand_delay   : natural range 0 to MAX_DELAY;
    variable seed1, seed2 : positive;
    variable sum_s40      : signed(39 downto 0);
  begin
    seed1    := 1;
    seed2    := 1;
    in_data  <= (others => (others => '0'));
    in_valid <= '0';
    wait for CLK_PERIOD * 10;
    for i in 0 to ITERATIONS - 1 loop
      -- Generate input vector with random data values
      wait until rising_edge(clk);
      in_valid <= '1';
      sum_s40  := (others => '0');
      for j in 0 to 255 loop
        uniform(seed1, seed2, rand_real); -- generates pseudo-random number in the open interval (0.0, 1.0)
        rand_data  := integer((rand_real - 0.5) * 4294967296.0);
        in_data(j) <= std_logic_vector(to_signed(rand_data, 32));
        sum_s40    := sum_s40 + rand_data;
      end loop;
      expected_out_data(i) <= sum_s40;
      report "Apply input vector " & to_string(i);
      -- Insert random delay between input vectors
      uniform(seed1, seed2, rand_real);
      rand_delay           := natural(rand_real * real(MAX_DELAY));
      for k in 0 to rand_delay - 1 loop
        wait until rising_edge(clk);
        in_valid <= '0';
      end loop;
    end loop;
    wait until rising_edge(clk);
    in_valid <= '0';
    wait;
  end process stimulus;

  -- Check adder results
  check : process
  begin
    for i in 0 to ITERATIONS - 1 loop
      wait on clk until rising_edge(clk) and out_valid = '1';
      report "Check output value " & to_string(i);
      assert signed(out_data) = expected_out_data(i)
      report "expected sum: " & to_string(expected_out_data(i)) & ", actual sum: " & to_string(signed(out_data)) severity failure;
    end loop;
    report "Simulation completed successfully (" & to_string(ITERATIONS) & " vectors)";
    std.env.stop;
  end process check;

  -- Unit under test
  uut : entity work.parallel
    port map(
      clk       => clk,
      in_data   => in_data,
      in_valid  => in_valid,
      out_data  => out_data,
      out_valid => out_valid
    );

end architecture RTL;

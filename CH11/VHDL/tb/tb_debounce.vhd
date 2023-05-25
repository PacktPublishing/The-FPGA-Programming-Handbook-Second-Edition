-- tb_debounce.sv
-- ------------------------------------
-- Simple debouncer circuit testbench
-- ------------------------------------
-- Author : Frank Bruno
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use std.env.finish;

entity tb_debounce is
end entity tb_debounce;

architecture tb of tb_debounce is
  procedure wait_nclk(signal clk: std_ulogic; n: positive) is
  begin
    for i in 1 to n loop
      wait until rising_edge(clk);
    end loop;
  end procedure wait_nclk;
  constant CYCLES  : integer := 16;
  signal clk     : std_logic := '0';
  signal reset   : std_logic := '0';
  signal sig_in  : std_logic := '0';
  signal sig_out : std_logic;
begin

  clk <= not clk after 10 ns;

  u_debounce : entity work.debounce
    generic map(CYCLES    => CYCLES)
    port map   (clk       => clk,
                reset     => reset,
                sig_in    => sig_in,
                sig_out   => sig_out);

  stim : process
  begin

    -- Test that we don't switch states too soon
    for i in 0 to CYCLES loop
      sig_in     <= '1';
      wait_nclk(clk, i);
      sig_in     <= '0';
      wait_nclk(clk, CYCLES-i);
    end loop;
    sig_in     <= '1';
    wait_nclk(clk, 100);
    for i in 0 to CYCLES loop
      sig_in     <= '0';
      wait_nclk(clk, i);
      sig_in     <= '1';
      wait_nclk(clk, CYCLES-i);
    end loop;
    sig_in     <= '0';
    wait_nclk(clk, 100);
    report "Test Finished!";
    finish;
  end process stim;
end architecture tb;

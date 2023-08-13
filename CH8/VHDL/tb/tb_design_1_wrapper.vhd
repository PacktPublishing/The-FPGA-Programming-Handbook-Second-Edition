-- tb_design_1_wrapper.vhd
-- ------------------------------------
-- temperature Sensor simple testbench
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- this testbench just provides the startup conditions to see how the
-- temperature sensor starts and samples. It doesn't generate inputs.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_design_1_wrapper is
end entity tb_design_1_wrapper;

architecture test of tb_design_1_wrapper is

  constant INTERVAL     : natural                       := 5000; -- ns
  constant NUM_SEGMENTS : natural                       := 8;
  constant CLK_PER      : natural                       := 10; -- ns
  constant SMOOTHING    : natural                       := 16;
  constant TEMP         : std_logic_vector(15 downto 0) := 9d"20" & 4d"8" & "XXX"; -- 20.5 deg (C) / 328 / 0x148

  signal clk            : std_logic                     := '0';
  signal reset          : std_logic;

  -- Temperature Sensor Interface
  signal TMP_SCL : std_logic;
  signal TMP_SDA : std_logic;
  signal TMP_INT : std_logic;
  signal TMP_CT  : std_logic;

  -- 7 segment display
  signal anode   : std_logic_vector(NUM_SEGMENTS - 1 downto 0);
  signal cathode : std_logic_vector(7 downto 0);

begin

  clk <= not clk after (CLK_PER * 1 ns) / 2;
  reset <= '0', '1' after CLK_PER * 10 * 1 ns;

  uut : entity work.design_1_wrapper
    port map (
      LED => open,
      SW => '0',
      TMP_SCL => TMP_SCL,
      TMP_SDA => TMP_SDA,
      anode => open,
      cathode => open,
      reset => reset,
      sys_clock => clk
    );

  adt7420 : entity work.adt7420_mdl
    generic map(
      I2C_ADDR => 7x"4B"
    )
    port map(
      temp => TEMP,
      scl  => TMP_SCL,
      sda  => TMP_SDA
    );

  -- Simulate I2C pull-ups on the board
  TMP_SCL <= 'H';
  TMP_SDA <= 'H';

end architecture test;


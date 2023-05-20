-- seven_segment.vhd
-- ------------------------------------
-- Drive multiple seven segment displays
-- ------------------------------------
-- Author : Frank Bruno
-- Encapsulate multiple seven segment displays using the cathode driver plus an
-- anode driver.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
USE WORK.counting_buttons_pkg.all;

entity seven_segment is
  generic (NUM_SEGMENTS : integer := 8;
           CLK_PER      : integer := 10;    -- Clock period in ns
           REFR_RATE    : integer := 1000); -- Refresh rate in Hz
  port (clk         : in std_logic;
        reset       : in std_logic; -- active high reset
        encoded     : in array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0);
        digit_point : in std_logic_vector(NUM_SEGMENTS-1 downto 0);
        anode       : out std_logic_vector(NUM_SEGMENTS-1 downto 0);
        cathode     : out std_logic_vector(7 downto 0));
end entity seven_segment;
architecture rtl of seven_segment is
  constant INTERVAL : integer := integer(100000000.0 / (CLK_PER * REFR_RATE));
  --signal refresh_count : std_logic_vector(natural(log2(real(INTERVAL)))-1 downto 0) := (others => '0');
  signal refresh_count : integer range 0 to INTERVAL := 0;
  signal anode_count : integer range 0 to NUM_SEGMENTS := 0;
  signal segments : array_t(NUM_SEGMENTS-1 downto 0)(7 downto 0);
begin

  g_genarray : for i in 0 to NUM_SEGMENTS-1 generate
    ct : entity work.cathode_top
      port map (clk         => clk,
                encoded     => encoded(i),
                digit_point => digit_point(i),
                cathode     => segments(i));
  end generate;

  process (clk)
  begin
    if rising_edge(clk) then
      if refresh_count = INTERVAL then
        refresh_count <= 0;
        if anode_count = NUM_SEGMENTS - 1 then
          anode_count <= 0;
        else
          anode_count   <= anode_count + 1;
        end if;
      else
        refresh_count <= refresh_count + 1;
      end if;
      anode              <= (others => '1');
      anode(anode_count) <= '0';
      cathode            <= segments(anode_count);
      if reset then
        refresh_count <= 0;
        anode_count   <= 0;
      end if;
    end if;
  end process;
end architecture rtl;
